import AVFoundation
import MediaPlayer
import SwiftUI
import ActivityKit

@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentItemTitle: String = ""
    @Published private(set) var progress: Double = 0
    @Published private(set) var queue: [SpeechItem] = []
    @Published private(set) var currentIndex: Int = 0

    private let synthesizer = AVSpeechSynthesizer()
    // The current item is spoken as one utterance per sentence (with a short
    // pause between them — sounds far less rushed than one long utterance).
    // Track the last utterance to know when the item is done, and each
    // utterance's character offset to report progress across the whole item.
    private var itemUtterances: [AVSpeechUtterance] = []
    private var utteranceProgressBase: [ObjectIdentifier: (offset: Int, total: Int)] = [:]
    private var lastProgressUpdate: Double = -1
    private let liveActivityService = LiveActivityService()
    private var currentAccentColorHex: String = "FF9500"

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    func speak(_ items: [SpeechItem], accentColorHex: String = "FF9500") {
        guard !items.isEmpty else { return }
        currentAccentColorHex = accentColorHex
        queue = items
        currentIndex = 0
        speakCurrent()
        liveActivityService.startActivity(
            totalEvents: items.count,
            firstEvent: items[0].title,
            firstTime: "",
            accentColorHex: accentColorHex
        )
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
        updateNowPlayingInfo()
        // Dismiss the Dynamic Island immediately on pause so it doesn't linger
        Task { await liveActivityService.stop() }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent()
        }
        isPaused = false
        isPlaying = true
        updateNowPlayingInfo()
        // Restart the Dynamic Island when resuming
        guard currentIndex < queue.count else { return }
        liveActivityService.startActivity(
            totalEvents: queue.count,
            firstEvent: queue[currentIndex].title,
            firstTime: "",
            accentColorHex: currentAccentColorHex
        )
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentItemTitle = ""
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Task { await liveActivityService.stop() }
    }

    /// Speaks a short sample with the given voice. Any running briefing is
    /// stopped first so playback state and Dynamic Island can't go stale.
    func preview(text: String, voice: AVSpeechSynthesisVoice) {
        if isPlaying || isPaused { stop() }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func skipForward() {
        synthesizer.stopSpeaking(at: .immediate)
        guard currentIndex + 1 < queue.count else {
            stop()
            return
        }
        currentIndex += 1
        speakCurrent()
    }

    func skipBackward() {
        synthesizer.stopSpeaking(at: .immediate)
        guard currentIndex > 0 else {
            speakCurrent()
            return
        }
        currentIndex -= 1
        speakCurrent()
    }

    private func speakCurrent() {
        guard currentIndex < queue.count else {
            isPlaying = false
            return
        }
        let item = queue[currentIndex]
        currentItemTitle = item.title
        progress = 0
        lastProgressUpdate = -1

        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let voice = bestVoice(for: item.language)
        let sentences = Self.sentenceChunks(item.text)
        let totalCharacters = max(sentences.reduce(0) { $0 + $1.count }, 1)

        itemUtterances = []
        utteranceProgressBase = [:]
        var offset = 0
        for (index, sentence) in sentences.enumerated() {
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.volume = 1.0
            // Breathing pause between sentences; none after the last one so
            // the next queue item follows without a double gap.
            utterance.postUtteranceDelay = index == sentences.count - 1 ? 0 : 0.15
            utteranceProgressBase[ObjectIdentifier(utterance)] = (offset, totalCharacters)
            itemUtterances.append(utterance)
            offset += sentence.count
            synthesizer.speak(utterance)
        }
        isPlaying = true
        isPaused = false
        updateNowPlayingInfo()
    }

    /// Splits text into sentences so each becomes its own utterance.
    /// Falls back to the whole text if sentence enumeration finds nothing.
    static func sentenceChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                chunks.append(s)
            }
        }
        return chunks.isEmpty ? [text] : chunks
    }

    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let candidates = Self.qualityFilteredVoices(for: languageCode)

        if let savedID = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedVoiceIdentifier),
           let saved = candidates.first(where: { $0.identifier == savedID }) {
            return saved
        }

        let sorted = Self.sortedByQuality(candidates)
        return sorted.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }

    /// All installed voices for a language, with Eloquence/novelty/humor formant voices excluded.
    static func qualityFilteredVoices(for languageCode: String) -> [AVSpeechSynthesisVoice] {
        let prefix = languageCode.prefix(2).lowercased()
        return AVSpeechSynthesisVoice.speechVoices().filter { v in
            let id = v.identifier.lowercased()
            // Eloquence voices (Eddy, Flo, Sandy, …) are ancient robotic
            // formant voices — never use them. Same for novelty/humor voices.
            return v.language.lowercased().hasPrefix(prefix)
                && !id.contains("eloquence")
                && !id.contains("novelty")
                && !id.contains("humor")
        }
    }

    static func sortedByQuality(_ voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        voices.sorted { lhs, rhs in
            // 1. Quality tier: premium (3) > enhanced (2) > default (1)
            if lhs.quality.rawValue != rhs.quality.rawValue {
                return lhs.quality.rawValue > rhs.quality.rawValue
            }
            // 2. Siri-branded voices
            let lSiri = lhs.identifier.lowercased().contains("siri")
            let rSiri = rhs.identifier.lowercased().contains("siri")
            if lSiri != rSiri { return lSiri }
            // 3. Prefer female
            return lhs.gender == .female && rhs.gender != .female
        }
    }

    /// True if no Enhanced/Premium voice is installed for the given language —
    /// used to prompt the user to download one for better quality.
    static func onlyDefaultQualityAvailable(for languageCode: String) -> Bool {
        !qualityFilteredVoices(for: languageCode).contains { $0.quality != .default }
    }

    private func setupAudioSession() {
        do {
            // .playback ignores the silent switch; .mixWithOthers lets the briefing
            // play over music/podcasts instead of stopping them
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipBackward() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: "Sunwake",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // AVSpeechUtterance is not Sendable — only its identity crosses into
        // the MainActor task.
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Items are spoken as several sentence utterances — only the last
            // one finishing means the item is done.
            guard let last = self.itemUtterances.last, ObjectIdentifier(last) == utteranceID else { return }
            if self.currentIndex + 1 < self.queue.count {
                self.currentIndex += 1
                self.speakCurrent()
                let next = self.currentIndex + 1 < self.queue.count ? self.queue[self.currentIndex + 1].title : nil
                await self.liveActivityService.update(
                    currentTitle: self.queue[self.currentIndex].title,
                    currentTime: "",
                    nextTitle: next,
                    nextTime: nil,
                    isPlaying: true,
                    progress: Double(self.currentIndex) / Double(self.queue.count),
                    index: self.currentIndex
                )
            } else {
                self.isPlaying = false
                self.currentItemTitle = ""
                await self.liveActivityService.stop()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        let location = characterRange.location
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let base = self.utteranceProgressBase[utteranceID] else { return }
            let newProgress = Double(base.offset + location) / Double(base.total)
            guard abs(newProgress - self.lastProgressUpdate) >= 0.02 else { return }
            self.lastProgressUpdate = newProgress
            self.progress = newProgress
        }
    }
}

struct SpeechItem: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let language: String
}

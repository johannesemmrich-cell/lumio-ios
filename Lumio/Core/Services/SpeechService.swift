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
    private var currentUtterance: AVSpeechUtterance?
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

        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: item.text)
        utterance.voice = bestVoice(for: item.language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.25
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
        updateNowPlayingInfo()
    }

    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let prefix = languageCode.prefix(2).lowercased()
        let all = AVSpeechSynthesisVoice.speechVoices()

        let candidates = all.filter { v in
            let id = v.identifier.lowercased()
            // Eloquence voices (Eddy, Flo, Sandy, …) are ancient robotic
            // formant voices — never use them. Same for novelty/humor voices.
            return v.language.lowercased().hasPrefix(prefix)
                && !id.contains("eloquence")
                && !id.contains("novelty")
                && !id.contains("humor")
        }

        let sorted = candidates.sorted { lhs, rhs in
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

        return sorted.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }

    private func setupAudioSession() {
        do {
            // .playback ignores the silent switch; no .mixWithOthers so we own the audio route
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
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
            MPMediaItemPropertyArtist: "Lumio",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
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
        let total = Double(utterance.speechString.count)
        guard total > 0 else { return }
        let newProgress = Double(characterRange.location) / total
        Task { @MainActor [weak self] in
            guard let self else { return }
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

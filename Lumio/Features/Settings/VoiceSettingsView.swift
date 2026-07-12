import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var speechService: SpeechService

    @State private var selectedVoiceID: String? = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedVoiceIdentifier)

    private var languageCode: String { appState.selectedLanguage == "de" ? "de-DE" : "en-US" }

    private var voices: [AVSpeechSynthesisVoice] {
        SpeechService.sortedByQuality(SpeechService.qualityFilteredVoices(for: languageCode))
    }

    private var onlyDefaultQuality: Bool {
        SpeechService.onlyDefaultQualityAvailable(for: languageCode)
    }

    private var sampleText: String {
        loc("Guten Morgen! Das ist ein Beispiel für deine Vorlese-Stimme.",
            "Good morning! This is a preview of your read-aloud voice.")
    }

    var body: some View {
        List {
            if onlyDefaultQuality {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc("Bessere Stimmen verfügbar", "Better voices available"), systemImage: "waveform")
                            .font(LumioTypography.callout.weight(.semibold))
                        Text(loc(
                            "Auf diesem Gerät ist nur die Standard-Stimme installiert. Für natürlicheren Klang: Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen → eine Enhanced- oder Premium-Stimme herunterladen.",
                            "Only the standard-quality voice is installed on this device. For a more natural sound: Settings → Accessibility → Spoken Content → Voices → download an Enhanced or Premium voice."
                        ))
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(loc("Einstellungen öffnen", "Open Settings"))
                        }
                        .font(LumioTypography.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(voices, id: \.identifier) { voice in
                    Button {
                        select(voice)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .font(LumioTypography.callout)
                                    .foregroundStyle(.primary)
                                Text(qualityLabel(voice.quality))
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                speechService.preview(text: sampleText, voice: voice)
                            } label: {
                                Image(systemName: "play.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(appState.accentColor)

                            if isSelected(voice) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(appState.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(loc("Verfügbare Stimmen", "Available voices"))
            } footer: {
                Text(loc(
                    "Ohne Auswahl wählt Lumio automatisch die beste verfügbare Stimme.",
                    "Without a selection, Lumio automatically picks the best available voice."
                ))
                .font(LumioTypography.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(loc("Stimme", "Voice"))
    }

    private func isSelected(_ voice: AVSpeechSynthesisVoice) -> Bool {
        selectedVoiceID == voice.identifier
    }

    private func select(_ voice: AVSpeechSynthesisVoice) {
        selectedVoiceID = voice.identifier
        UserDefaults.standard.set(voice.identifier, forKey: UserDefaultsKey.selectedVoiceIdentifier)
        speechService.preview(text: sampleText, voice: voice)
    }

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:  return loc("Premium", "Premium")
        case .enhanced: return loc("Enhanced", "Enhanced")
        default:        return loc("Standard", "Standard")
        }
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}

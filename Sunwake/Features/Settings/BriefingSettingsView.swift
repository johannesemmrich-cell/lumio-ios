import SwiftUI

struct BriefingSettingsView: View {
    @EnvironmentObject private var appState: AppState

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        List {
            Section {
                ForEach(BriefingLength.allCases, id: \.self) { length in
                    HStack {
                        Text(length.displayName)
                            .font(SunwakeTypography.body)
                        Spacer()
                        if appState.briefingLength == length {
                            Image(systemName: "checkmark")
                                .foregroundStyle(appState.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.briefingLength = length }
                }
            } header: {
                Text(loc("Länge", "Length"))
            } footer: {
                Text(loc("Kurz: 1 Satz · Mittel: 3 Sätze · Lang: 5 Sätze", "Short: 1 sentence · Medium: 3 sentences · Long: 5 sentences"))
                    .font(SunwakeTypography.caption)
            }

            Section {
                ForEach(BriefingStyle.allCases, id: \.self) { style in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .font(SunwakeTypography.body)
                            Text(style.descriptionText(language: appState.selectedLanguage))
                                .font(SunwakeTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.briefingStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundStyle(appState.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.briefingStyle = style }
                }
            } header: {
                Text(loc("Stil", "Style"))
            }
        }
        .navigationTitle(loc("Briefing-Einstellungen", "Briefing Settings"))
        .listStyle(.insetGrouped)
        .tint(appState.accentColor)
        .toolbar {
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Settings", feature: "Briefing Settings", element: "Toolbar")
                }
            }
        }
    }
}

private extension BriefingStyle {
    func descriptionText(language: String) -> String {
        let isDE = language == "de"
        switch self {
        case .friendly: return isDE ? "Warm und motivierend" : "Warm and encouraging"
        case .formal:   return isDE ? "Sachlich und präzise" : "Professional and precise"
        case .concise:  return isDE ? "Sehr knapp gehalten" : "Kept very brief"
        }
    }
}

import SwiftUI

struct BriefingSettingsView: View {
    @EnvironmentObject private var appState: AppState

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
                                .foregroundStyle(Color.sunwakeAccent)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.briefingLength = length }
                }
            } header: {
                Text("Länge")
            } footer: {
                Text("Kurz: 1 Satz · Mittel: 3 Sätze · Lang: 5 Sätze")
                    .font(SunwakeTypography.caption)
            }

            Section {
                ForEach(BriefingStyle.allCases, id: \.self) { style in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .font(SunwakeTypography.body)
                            Text(style.descriptionText)
                                .font(SunwakeTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.briefingStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.sunwakeAccent)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.briefingStyle = style }
                }
            } header: {
                Text("Stil")
            }
        }
        .navigationTitle("Briefing-Einstellungen")
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
    var descriptionText: String {
        switch self {
        case .friendly: return "Warm und motivierend"
        case .formal:   return "Sachlich und präzise"
        case .concise:  return "Sehr knapp gehalten"
        }
    }
}

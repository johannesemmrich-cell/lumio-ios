import SwiftUI
import EventKit

struct ReminderSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var calendars: [EKCalendar] = []
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var excludedIDs: Set<String> = ReminderExclusionStore.excludedIDs

    private let store = EKEventStore()

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        List {
            if authStatus != .fullAccess {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc("Zugriff auf Erinnerungen erforderlich", "Reminders access required"), systemImage: "exclamationmark.triangle")
                            .font(SunwakeTypography.body.weight(.medium))
                        Text(loc("Erlaube Sunwake den Zugriff auf Erinnerungen in den Systemeinstellungen.", "Allow Sunwake access to Reminders in System Settings."))
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.secondary)
                        Button(loc("Einstellungen öffnen", "Open Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(SunwakeTypography.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            } else if calendars.isEmpty {
                Section {
                    Text(loc("Keine Erinnerungs-Listen gefunden.", "No reminder lists found."))
                        .foregroundStyle(.secondary)
                        .font(SunwakeTypography.caption)
                }
            } else {
                Section {
                    ForEach(calendars, id: \.calendarIdentifier) { cal in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 12, height: 12)
                            Text(cal.title)
                                .font(SunwakeTypography.body)
                            Spacer()
                            if !excludedIDs.contains(cal.calendarIdentifier) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(appState.accentColor)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if excludedIDs.contains(cal.calendarIdentifier) {
                                excludedIDs.remove(cal.calendarIdentifier)
                            } else {
                                excludedIDs.insert(cal.calendarIdentifier)
                            }
                            ReminderExclusionStore.excludedIDs = excludedIDs
                        }
                    }
                } header: {
                    Text(loc("Angezeigte Listen", "Visible lists"))
                } footer: {
                    Text(loc("Deaktivierte Listen werden nicht im Briefing und im Heute-Tab angezeigt.", "Disabled lists won't appear in the briefing or the Today tab."))
                        .font(SunwakeTypography.caption)
                }

                Section {
                    Button {
                        ReminderExclusionStore.excludedIDs = []
                        excludedIDs = []
                    } label: {
                        Label(loc("Alle aktivieren", "Enable all"), systemImage: "checkmark.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(loc("Erinnerungen", "Reminders"))
        .listStyle(.insetGrouped)
        .task {
            authStatus = EKEventStore.authorizationStatus(for: .reminder)
            if authStatus == .fullAccess {
                calendars = store.calendars(for: .reminder)
            }
        }
    }
}

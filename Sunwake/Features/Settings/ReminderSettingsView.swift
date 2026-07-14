import SwiftUI
import EventKit

struct ReminderSettingsView: View {
    @State private var calendars: [EKCalendar] = []
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var excludedIDs: Set<String> = ReminderExclusionStore.excludedIDs

    private let store = EKEventStore()

    var body: some View {
        List {
            if authStatus != .fullAccess {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Zugriff auf Erinnerungen erforderlich", systemImage: "exclamationmark.triangle")
                            .font(SunwakeTypography.body.weight(.medium))
                        Text("Erlaube Sunwake den Zugriff auf Erinnerungen in den Systemeinstellungen.")
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.secondary)
                        Button("Einstellungen öffnen") {
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
                    Text("Keine Erinnerungs-Listen gefunden.")
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
                                    .foregroundStyle(Color.accentColor)
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
                    Text("Angezeigte Listen")
                } footer: {
                    Text("Deaktivierte Listen werden nicht im Briefing und im Heute-Tab angezeigt.")
                        .font(SunwakeTypography.caption)
                }

                Section {
                    Button {
                        ReminderExclusionStore.excludedIDs = []
                        excludedIDs = []
                    } label: {
                        Label("Alle aktivieren", systemImage: "checkmark.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Erinnerungen")
        .listStyle(.insetGrouped)
        .task {
            authStatus = EKEventStore.authorizationStatus(for: .reminder)
            if authStatus == .fullAccess {
                calendars = store.calendars(for: .reminder)
            }
        }
    }
}

import SwiftUI
import EventKit

struct ReminderSettingsView: View {
    @State private var calendars: [EKCalendar] = []
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var excludedIDs: Set<String> = ReminderExclusionStore.excludedIDs

    private let service = CalendarService()

    var body: some View {
        List {
            if authStatus != .fullAccess {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Zugriff auf Erinnerungen erforderlich", systemImage: "exclamationmark.triangle")
                            .font(LumioTypography.body.weight(.medium))
                        Text("Erlaube Lumio den Zugriff auf Erinnerungen in den Systemeinstellungen.")
                            .font(LumioTypography.caption)
                            .foregroundStyle(.secondary)
                        Button("Einstellungen öffnen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(LumioTypography.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            } else if calendars.isEmpty {
                Section {
                    Text("Keine Erinnerungs-Listen gefunden.")
                        .foregroundStyle(.secondary)
                        .font(LumioTypography.caption)
                }
            } else {
                Section {
                    ForEach(calendars, id: \.calendarIdentifier) { cal in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(cgColor: cal.cgColor))
                                .frame(width: 12, height: 12)
                            Text(cal.title)
                                .font(LumioTypography.body)
                            Spacer()
                            if !excludedIDs.contains(cal.calendarIdentifier) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            ReminderExclusionStore.toggle(cal.calendarIdentifier)
                            excludedIDs = ReminderExclusionStore.excludedIDs
                        }
                    }
                } header: {
                    Text("Angezeigte Listen")
                } footer: {
                    Text("Deaktivierte Listen werden nicht im Briefing und im Heute-Tab angezeigt.")
                        .font(LumioTypography.caption)
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
                calendars = service.availableReminderCalendars()
            }
        }
    }
}

import SwiftUI

struct BriefingScheduleView: View {
    // Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    @State private var selectedDays: Set<Int> = {
        let saved = UserDefaults.standard.array(forKey: UserDefaultsKey.briefingScheduleDays) as? [Int]
        return Set(saved ?? [2, 3, 4, 5, 6])
    }()

    @State private var scheduleTime: Date = {
        var comps = DateComponents()
        let savedHour = UserDefaults.standard.integer(forKey: UserDefaultsKey.briefingScheduleHour)
        let savedMinute = UserDefaults.standard.integer(forKey: UserDefaultsKey.briefingScheduleMinute)
        comps.hour = savedHour == 0 ? 7 : savedHour
        comps.minute = savedMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private let weekdayNames: [(Int, String)] = [
        (2, "Mo"), (3, "Di"), (4, "Mi"), (5, "Do"), (6, "Fr"), (7, "Sa"), (1, "So")
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tage")
                        .font(LumioTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(weekdayNames, id: \.0) { weekday, label in
                            DayToggleButton(
                                label: label,
                                isSelected: selectedDays.contains(weekday)
                            ) {
                                if selectedDays.contains(weekday) {
                                    selectedDays.remove(weekday)
                                } else {
                                    selectedDays.insert(weekday)
                                }
                                saveAndSchedule()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                DatePicker("Uhrzeit", selection: $scheduleTime, displayedComponents: .hourAndMinute)
                    .onChange(of: scheduleTime) { _, _ in
                        saveAndSchedule()
                    }
            } header: {
                Text("Briefing-Zeitplan")
            } footer: {
                if selectedDays.isEmpty {
                    Text("Kein Tag ausgewählt — du erhältst keine Briefing-Benachrichtigungen.")
                        .font(LumioTypography.caption)
                } else {
                    Text("Du erhältst dein Briefing an den markierten Tagen um \(formattedTime).")
                        .font(LumioTypography.caption)
                }
            }

            Section {
                Button {
                    selectedDays = Set(2...6)
                    saveAndSchedule()
                } label: {
                    Label("Mo–Fr auswählen", systemImage: "briefcase")
                        .foregroundStyle(.primary)
                }

                Button {
                    selectedDays = Set(1...7)
                    saveAndSchedule()
                } label: {
                    Label("Alle Tage", systemImage: "calendar")
                        .foregroundStyle(.primary)
                }

                Button(role: .destructive) {
                    selectedDays = []
                    saveAndSchedule()
                } label: {
                    Label("Benachrichtigungen deaktivieren", systemImage: "bell.slash")
                }
            } header: {
                Text("Schnellauswahl")
            }
        }
        .navigationTitle("Briefing-Zeitplan")
        .listStyle(.insetGrouped)
    }

    private var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: scheduleTime)
    }

    private func saveAndSchedule() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: scheduleTime)
        let hour = comps.hour ?? 7
        let minute = comps.minute ?? 0

        UserDefaults.standard.set(Array(selectedDays), forKey: UserDefaultsKey.briefingScheduleDays)
        UserDefaults.standard.set(hour, forKey: UserDefaultsKey.briefingScheduleHour)
        UserDefaults.standard.set(minute, forKey: UserDefaultsKey.briefingScheduleMinute)

        Task {
            await NotificationService.shared.scheduleBriefings(
                days: selectedDays,
                hour: hour,
                minute: minute,
                previewText: String(localized: "Tap to see your morning briefing.")
            )
        }
    }
}

private struct DayToggleButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.lumioAccent.opacity(0.15) : Color(uiColor: .tertiarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isSelected ? Color.lumioAccent.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                )
                .foregroundStyle(isSelected ? Color.lumioAccent : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.18), value: isSelected)
    }
}

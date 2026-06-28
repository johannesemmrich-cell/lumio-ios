import SwiftUI

private struct WeekdayEntry: Identifiable {
    let id: Int        // Calendar weekday (1=Sun, 2=Mon … 7=Sat)
    let short: String
    let long: String
}

private let weekdays: [WeekdayEntry] = [
    .init(id: 2, short: "Mo", long: "Montag"),
    .init(id: 3, short: "Di", long: "Dienstag"),
    .init(id: 4, short: "Mi", long: "Mittwoch"),
    .init(id: 5, short: "Do", long: "Donnerstag"),
    .init(id: 6, short: "Fr", long: "Freitag"),
    .init(id: 7, short: "Sa", long: "Samstag"),
    .init(id: 1, short: "So", long: "Sonntag"),
]

struct BriefingScheduleView: View {
    @State private var enabledDays: Set<Int>
    @State private var dayTimes: [Int: Date]

    init() {
        let saved = UserDefaults.standard.array(forKey: UserDefaultsKey.briefingScheduleDays) as? [Int]
        _enabledDays = State(initialValue: Set(saved ?? [2, 3, 4, 5, 6]))

        var times: [Int: Date] = [:]
        for w in 1...7 {
            let h = UserDefaults.standard.integer(forKey: UserDefaultsKey.briefingHourKey(w))
            let m = UserDefaults.standard.integer(forKey: UserDefaultsKey.briefingMinuteKey(w))
            var comps = DateComponents()
            comps.hour = h == 0 ? 7 : h
            comps.minute = m
            times[w] = Calendar.current.date(from: comps) ?? Date()
        }
        _dayTimes = State(initialValue: times)
    }

    var body: some View {
        List {
            Section {
                ForEach(weekdays) { entry in
                    weekdayRow(entry)
                }
            } header: {
                Text("Zeitplan")
            } footer: {
                if enabledDays.isEmpty {
                    Text("Kein Tag aktiv — du erhältst keine Briefing-Benachrichtigungen.")
                        .font(LumioTypography.caption)
                } else {
                    Text(footerText)
                        .font(LumioTypography.caption)
                }
            }

            Section {
                Button {
                    enabledDays = Set(2...6)
                    saveAndSchedule()
                } label: {
                    Label("Mo–Fr aktivieren", systemImage: "briefcase")
                        .foregroundStyle(.primary)
                }
                Button {
                    enabledDays = Set(1...7)
                    saveAndSchedule()
                } label: {
                    Label("Alle Tage aktivieren", systemImage: "calendar")
                        .foregroundStyle(.primary)
                }
                Button(role: .destructive) {
                    enabledDays = []
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

    @ViewBuilder
    private func weekdayRow(_ entry: WeekdayEntry) -> some View {
        let isEnabled = enabledDays.contains(entry.id)

        HStack {
            Text(entry.long)
                .font(LumioTypography.body)
            Spacer()
            if isEnabled {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dayTimes[entry.id] ?? defaultTime() },
                        set: { newDate in
                            dayTimes[entry.id] = newDate
                            saveAndSchedule()
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .fixedSize()
                .padding(.trailing, 8)
            }
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { on in
                    if on { enabledDays.insert(entry.id) } else { enabledDays.remove(entry.id) }
                    saveAndSchedule()
                }
            ))
            .labelsHidden()
            .fixedSize()
        }
    }

    private func defaultTime() -> Date {
        var c = DateComponents(); c.hour = 7; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private var footerText: String {
        let sorted = weekdays.filter { enabledDays.contains($0.id) }
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        let parts = sorted.map { entry -> String in
            let time = dayTimes[entry.id].map { fmt.string(from: $0) } ?? "07:00"
            return "\(entry.short) \(time)"
        }
        return "Briefing-Benachrichtigungen: " + parts.joined(separator: ", ")
    }

    private func saveAndSchedule() {
        UserDefaults.standard.set(Array(enabledDays), forKey: UserDefaultsKey.briefingScheduleDays)

        var dayTimePairs: [Int: (hour: Int, minute: Int)] = [:]
        for weekday in enabledDays {
            let date = dayTimes[weekday] ?? defaultTime()
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            let h = comps.hour ?? 7
            let m = comps.minute ?? 0
            UserDefaults.standard.set(h, forKey: UserDefaultsKey.briefingHourKey(weekday))
            UserDefaults.standard.set(m, forKey: UserDefaultsKey.briefingMinuteKey(weekday))
            dayTimePairs[weekday] = (hour: h, minute: m)
        }

        Task {
            await NotificationService.shared.scheduleBriefings(
                dayTimes: dayTimePairs,
                previewText: String(localized: "Tap to see your morning briefing.")
            )
        }
    }
}

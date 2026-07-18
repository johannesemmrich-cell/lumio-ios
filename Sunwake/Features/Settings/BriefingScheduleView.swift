import SwiftUI

private struct WeekdayEntry: Identifiable {
    let id: Int        // Calendar weekday (1=Sun, 2=Mon … 7=Sat)
    let short: String
    let long: String
}

private let weekdaysDE: [WeekdayEntry] = [
    .init(id: 2, short: "Mo", long: "Montag"),
    .init(id: 3, short: "Di", long: "Dienstag"),
    .init(id: 4, short: "Mi", long: "Mittwoch"),
    .init(id: 5, short: "Do", long: "Donnerstag"),
    .init(id: 6, short: "Fr", long: "Freitag"),
    .init(id: 7, short: "Sa", long: "Samstag"),
    .init(id: 1, short: "So", long: "Sonntag"),
]

private let weekdaysEN: [WeekdayEntry] = [
    .init(id: 2, short: "Mon", long: "Monday"),
    .init(id: 3, short: "Tue", long: "Tuesday"),
    .init(id: 4, short: "Wed", long: "Wednesday"),
    .init(id: 5, short: "Thu", long: "Thursday"),
    .init(id: 6, short: "Fri", long: "Friday"),
    .init(id: 7, short: "Sat", long: "Saturday"),
    .init(id: 1, short: "Sun", long: "Sunday"),
]

struct BriefingScheduleView: View {
    @EnvironmentObject private var appState: AppState
    @State private var enabledDays: Set<Int>
    @State private var dayTimes: [Int: Date]

    private var weekdays: [WeekdayEntry] { appState.selectedLanguage == "de" ? weekdaysDE : weekdaysEN }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

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
                Text(loc("Zeitplan", "Schedule"))
            } footer: {
                if enabledDays.isEmpty {
                    Text(loc("Kein Tag aktiv — du erhältst keine Briefing-Benachrichtigungen.", "No day active — you won't receive briefing notifications."))
                        .font(SunwakeTypography.caption)
                } else {
                    Text(footerText)
                        .font(SunwakeTypography.caption)
                }
            }

            Section {
                Button {
                    enabledDays = Set(2...6)
                    saveAndSchedule()
                } label: {
                    Label(loc("Mo–Fr aktivieren", "Enable Mon–Fri"), systemImage: "briefcase")
                        .foregroundStyle(.primary)
                }
                Button {
                    enabledDays = Set(1...7)
                    saveAndSchedule()
                } label: {
                    Label(loc("Alle Tage aktivieren", "Enable all days"), systemImage: "calendar")
                        .foregroundStyle(.primary)
                }
                Button(role: .destructive) {
                    enabledDays = []
                    saveAndSchedule()
                } label: {
                    Label(loc("Benachrichtigungen deaktivieren", "Disable notifications"), systemImage: "bell.slash")
                }
            } header: {
                Text(loc("Schnellauswahl", "Quick selection"))
            }
        }
        .navigationTitle(loc("Briefing-Zeitplan", "Briefing schedule"))
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func weekdayRow(_ entry: WeekdayEntry) -> some View {
        let isEnabled = enabledDays.contains(entry.id)

        HStack {
            Text(entry.long)
                .font(SunwakeTypography.body)
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
        return loc("Briefing-Benachrichtigungen: ", "Briefing notifications: ") + parts.joined(separator: ", ")
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
                previewText: loc("Tippe für dein Morgen-Briefing.", "Tap to see your morning briefing."),
                language: appState.selectedLanguage
            )
        }
    }
}

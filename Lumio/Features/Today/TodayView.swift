import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    @StateObject private var speechService = SpeechService()

    @State private var showPaywall = false
    @State private var showCalendar = false
    @State private var showBriefingDetail = false
    @State private var showChatSheet = false
    @State private var showSettingsSheet = false
    @State private var showLibrarySheet = false
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var headerOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        TodayHeaderView(
                            summary: viewModel.aiSummary,
                            isGenerating: viewModel.isGeneratingAI,
                            onSummaryTap: { showBriefingDetail = true }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        if let weather = viewModel.weather {
                            WeatherCard(weather: weather, accentColor: appState.accentColor)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                        }

                        if viewModel.events.isEmpty && viewModel.reminders.isEmpty && !viewModel.isLoadingEvents {
                            EmptyDayView(accentColor: appState.accentColor)
                                .padding(.horizontal, 20)
                        } else {
                            eventsSection
                                .padding(.horizontal, 20)

                            if !viewModel.reminders.isEmpty {
                                remindersSection
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                            }
                        }

                        Spacer().frame(height: 120)
                    }
                }
                .refreshable {
                    viewModel.language = appState.selectedLanguage
                    viewModel.briefingLength = appState.briefingLength
                    viewModel.briefingStyle = appState.briefingStyle
                    await viewModel.refresh()
                }

                PlayBarView(speechService: speechService, events: viewModel.events, reminders: viewModel.reminders, weather: viewModel.weather, language: appState.selectedLanguage, accentColor: appState.accentColor, accentColorHex: appState.accentColorHex)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.08), radius: 20, y: -4)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(Array(appState.topBarActions.prefix(2)), id: \.self) { action in
                        Group {
                            switch action {
                            case "calendar":
                                Button { showCalendar = true } label: { Image(systemName: "calendar") }
                            case "chat_shortcut":
                                Button {
                                    if appState.tabOrder.contains(.chat) {
                                        appState.selectedTab = .chat
                                    } else {
                                        showChatSheet = true
                                    }
                                } label: { Image(systemName: "bubble.left.fill") }
                            case "library":
                                Button {
                                    if appState.tabOrder.contains(.library) {
                                        appState.selectedTab = .library
                                    } else {
                                        showLibrarySheet = true
                                    }
                                } label: { Image(systemName: "books.vertical.fill") }
                            case "settings":
                                Button {
                                    if appState.tabOrder.contains(.settings) {
                                        appState.selectedTab = .settings
                                    } else {
                                        showSettingsSheet = true
                                    }
                                } label: { Image(systemName: "gearshape") }
                            case "refresh":
                                Button { Task { await viewModel.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                                    .disabled(viewModel.isLoadingEvents)
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                if appState.isDeveloperModeActive {
                    ToolbarItem(placement: .topBarLeading) {
                        DeveloperFeedbackButton(screen: "Today", feature: "Daily Briefing", element: "Toolbar")
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                LumioCalendarView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showChatSheet) {
                NavigationStack { ChatView() }
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack { SettingsView() }
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showLibrarySheet) {
                NavigationStack { LibraryView() }
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showBriefingDetail) {
                NavigationStack {
                    BriefingDetailView(
                        fullSummary: viewModel.aiSummary,
                        events: viewModel.events,
                        reminders: viewModel.reminders,
                        weather: viewModel.weather,
                        language: appState.selectedLanguage,
                        accentColor: appState.accentColor,
                        accentColorHex: appState.accentColorHex,
                        speechService: speechService
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .environmentObject(subscriptionManager)
                .environmentObject(appState)
            }
            .task {
                viewModel.language = appState.selectedLanguage
                viewModel.briefingLength = appState.briefingLength
                viewModel.briefingStyle = appState.briefingStyle
                await viewModel.loadInitialData()
            }
            .onChange(of: appState.pendingBriefingForChat) { _, pending in
                guard pending != nil else { return }
                if appState.tabOrder.contains(.chat) {
                    appState.selectedTab = .chat
                } else {
                    showChatSheet = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.events.isEmpty {
                SectionHeader(title: "Today's Events", count: viewModel.events.count)
                    .padding(.bottom, 4)

                ForEach(viewModel.events) { event in
                    Button { HapticFeedback.selection(); selectedEvent = event } label: {
                        EventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .developerFeedbackOverlay(
                            isActive: appState.isDeveloperModeActive,
                            screen: "Today",
                            feature: "Events",
                            element: "Event: \(event.title)"
                        )
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Reminders", count: viewModel.reminders.count)
                .padding(.bottom, 4)

            ForEach(viewModel.reminders) { reminder in
                ReminderCard(reminder: reminder)
            }
        }
    }
}

// MARK: — Header

struct TodayHeaderView: View {
    @EnvironmentObject private var appState: AppState
    let summary: String
    let isGenerating: Bool
    var onSummaryTap: (() -> Void)? = nil

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        default: return String(localized: "Good evening")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(1)
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(LumioTypography.hero)
                }
                Spacer()
                DayProgressRing(accentColor: appState.accentColor)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Preparing your briefing…")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !summary.isEmpty {
                Button {
                    HapticFeedback.selection()
                    onSummaryTap?()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(summary)
                            .font(LumioTypography.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

struct DayProgressRing: View {
    let accentColor: Color

    private var progress: Double {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "sun.max.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: — Event Card

struct EventCard: View {
    let event: CalendarEvent

    private var timeString: String {
        if event.isAllDay { return String(localized: "All day") }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(LumioTypography.callout.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(timeString)
                        .font(LumioTypography.caption)
                }
                .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(LumioTypography.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isNow {
                Capsule()
                    .fill(Color.green.opacity(0.15))
                    .overlay(
                        Text("Now")
                            .font(LumioTypography.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    )
                    .frame(width: 44, height: 22)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var isNow: Bool {
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }
}

// MARK: — Play Bar

struct PlayBarView: View {
    @ObservedObject var speechService: SpeechService
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let weather: WeatherData?
    let language: String
    let accentColor: Color
    let accentColorHex: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if speechService.isPlaying {
                    Text(speechService.currentItemTitle)
                        .font(LumioTypography.caption.weight(.semibold))
                        .lineLimit(1)
                    ProgressView(value: speechService.progress)
                        .tint(accentColor)
                } else {
                    Text("Play briefing")
                        .font(LumioTypography.callout.weight(.semibold))
                    Text("Tap to hear your day read aloud")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipBackward()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.body.weight(.medium))
                    }
                }

                Button {
                    HapticFeedback.impact(.medium)
                    if speechService.isPlaying {
                        speechService.pause()
                    } else if speechService.isPaused {
                        speechService.resume()
                    } else {
                        let narrativeText = buildNarrativeBriefing(events: events, reminders: reminders, weather: weather, language: language)
                        let item = SpeechItem(
                            title: "Briefing",
                            text: narrativeText,
                            language: language == "de" ? "de-DE" : "en-US"
                        )
                        speechService.speak([item], accentColorHex: accentColorHex)
                    }
                } label: {
                    Image(systemName: speechService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }

                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipForward()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
        )
    }

    private func buildNarrativeBriefing(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, language: String) -> String {
        let isDE = language == "de"
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        if isDE {
            switch hour {
            case 5..<12: greeting = "Guten Morgen!"
            case 12..<17: greeting = "Hallo!"
            default: greeting = "Guten Abend!"
            }
        } else {
            switch hour {
            case 5..<12: greeting = "Good morning!"
            case 12..<17: greeting = "Hello!"
            default: greeting = "Good evening!"
            }
        }

        var parts: [String] = [greeting]

        // Weather
        if let w = weather {
            let temp = Int(w.temperatureCurrent.rounded())
            if isDE {
                parts.append("Das Wetter heute: \(w.conditionLabel), \(temp) Grad.")
            } else {
                parts.append("Today's weather: \(w.conditionLabel), \(temp) degrees.")
            }
        }

        // Events
        if events.isEmpty && reminders.isEmpty {
            parts.append(isDE
                ? "Du hast heute keine Termine oder Erinnerungen. Genieße den freien Tag!"
                : "You have no events or reminders today. Enjoy your free day!")
        } else {
            if !events.isEmpty {
                if isDE {
                    parts.append("Du hast \(events.count == 1 ? "einen Termin" : "\(events.count) Termine") heute.")
                } else {
                    parts.append("You have \(events.count == 1 ? "one event" : "\(events.count) events") today.")
                }

                for (index, event) in events.enumerated() {
                    let timeStr = event.isAllDay
                        ? (isDE ? "den ganzen Tag" : "all day")
                        : (isDE ? "um \(fmt.string(from: event.startDate)) Uhr" : "at \(fmt.string(from: event.startDate))")
                    let locationPart: String
                    if let loc = event.location, !loc.isEmpty {
                        locationPart = isDE ? ", in \(loc)," : ", at \(loc),"
                    } else {
                        locationPart = ""
                    }
                    let sentence: String
                    if index == 0 {
                        sentence = isDE
                            ? "Dein Tag startet \(timeStr) mit \(event.title)\(locationPart)."
                            : "Your day starts \(timeStr) with \(event.title)\(locationPart)."
                    } else if index == events.count - 1 {
                        sentence = isDE
                            ? "Und zum Abschluss hast du \(timeStr) \(event.title)\(locationPart)."
                            : "And to wrap up, you have \(event.title) \(timeStr)\(locationPart)."
                    } else {
                        let transitions = isDE
                            ? ["Danach", "Anschließend", "Im Anschluss"]
                            : ["Then", "After that,", "Next up:"]
                        let transition = transitions[index % transitions.count]
                        sentence = isDE
                            ? "\(transition) geht es \(timeStr) weiter mit \(event.title)\(locationPart)."
                            : "\(transition) \(event.title) \(timeStr)\(locationPart)."
                    }
                    parts.append(sentence)
                }
            }

            if !reminders.isEmpty {
                if isDE {
                    parts.append("Deine Erinnerungen für heute: \(reminders.prefix(3).map(\.title).joined(separator: ", ")).")
                } else {
                    parts.append("Your reminders today: \(reminders.prefix(3).map(\.title).joined(separator: ", ")).")
                }
            }
        }

        parts.append(isDE ? "Das war dein Briefing — einen schönen Tag!" : "That's your briefing — have a great day!")
        return parts.joined(separator: " ")
    }
}

// MARK: — Empty state

struct EmptyDayView: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(accentColor)
            Text("Clear day ahead")
                .font(LumioTypography.title3)
            Text("No events scheduled for today. Enjoy the open time.")
                .font(LumioTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(LumioTypography.headline)
            Spacer()
            Text("\(count)")
                .font(LumioTypography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
    }
}

// MARK: — Weather Card

struct WeatherCard: View {
    let weather: WeatherData
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: weather.sfSymbol)
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.conditionLabel)
                    .font(LumioTypography.callout.weight(.semibold))
                HStack(spacing: 8) {
                    Text("↑\(Int(weather.temperatureMax.rounded()))°")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("↓\(Int(weather.temperatureMin.rounded()))°")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                    if weather.windSpeed > 0 {
                        Text("· \(Int(weather.windSpeed.rounded())) km/h")
                            .font(LumioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("\(Int(weather.temperatureCurrent.rounded()))°")
                .font(.system(size: 32, weight: .light, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: — Reminder Card

struct ReminderCard: View {
    let reminder: ReminderItem

    private var timeString: String? {
        guard let due = reminder.dueDate else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: due)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "circle")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !reminder.priorityLabel.isEmpty {
                        Text(reminder.priorityLabel)
                            .font(LumioTypography.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    Text(reminder.title)
                        .font(LumioTypography.callout)
                        .lineLimit(2)
                }

                if let time = timeString {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(time)
                            .font(LumioTypography.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

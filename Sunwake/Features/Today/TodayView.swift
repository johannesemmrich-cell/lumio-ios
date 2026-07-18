import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    // Shared app-wide instance (injected in SunwakeApp) so only one playback
    // pipeline exists — see SpeechService for why two instances conflict.
    @EnvironmentObject private var speechService: SpeechService

    @State private var showPaywall = false
    @State private var showCalendar = false
    @State private var showBriefingDetail = false
    @State private var showChatSheet = false
    @State private var showSettingsSheet = false
    @State private var showLibrarySheet = false
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var headerOffset: CGFloat = 0
    @State private var showVoiceQualityHint = false
    @State private var showVoiceSettingsSheet = false

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
                            WeatherCard(weather: weather, accentColor: appState.accentColor, language: appState.selectedLanguage)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                        }

                        if viewModel.events.isEmpty && viewModel.reminders.isEmpty && !viewModel.isLoadingEvents {
                            EmptyDayView(accentColor: appState.accentColor, language: appState.selectedLanguage)
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

                        TomorrowPreviewCard(
                            isPremium: subscriptionManager.effectivelyPremium,
                            isLoading: viewModel.isLoadingTomorrow,
                            hasLoaded: viewModel.hasLoadedTomorrow,
                            summary: viewModel.tomorrowSummary,
                            events: viewModel.tomorrowEvents,
                            language: appState.selectedLanguage,
                            accentColor: appState.accentColor,
                            onUnlock: { showPaywall = true },
                            onLoad: { Task { await viewModel.loadTomorrowPreview() } }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Spacer().frame(height: 120)
                    }
                }
                .refreshable {
                    viewModel.language = appState.selectedLanguage
                    viewModel.briefingLength = appState.briefingLength
                    viewModel.briefingStyle = appState.briefingStyle
                    await viewModel.refresh()
                }

                VStack(spacing: 10) {
                    if showVoiceQualityHint {
                        VoiceQualityHintBanner(
                            language: appState.selectedLanguage,
                            accentColor: appState.accentColor,
                            onTap: { showVoiceSettingsSheet = true },
                            onDismiss: {
                                UserDefaults.standard.set(true, forKey: UserDefaultsKey.voiceQualityHintDismissed)
                                withAnimation(.easeInOut(duration: 0.2)) { showVoiceQualityHint = false }
                            }
                        )
                    }
                    PlayBarView(speechService: speechService, aiSummary: viewModel.aiSummary, events: viewModel.events, reminders: viewModel.reminders, weather: viewModel.weather, language: appState.selectedLanguage, accentColor: appState.accentColor, accentColorHex: appState.accentColorHex)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .shadow(color: .black.opacity(0.08), radius: 20, y: -4)
            }
            .sunwakeTabBackground()
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
                SunwakeCalendarView()
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
                refreshVoiceQualityHint()
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $showVoiceSettingsSheet, onDismiss: refreshVoiceQualityHint) {
                NavigationStack { VoiceSettingsView() }
                    .environmentObject(appState)
                    .environmentObject(speechService)
                    .tint(appState.accentColor)
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
                        EventCard(event: event, language: appState.selectedLanguage)
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

    /// Show the hint until the user dismisses it or an Enhanced/Premium voice
    /// is installed — the single biggest lever for a natural-sounding briefing.
    private func refreshVoiceQualityHint() {
        let dismissed = UserDefaults.standard.bool(forKey: UserDefaultsKey.voiceQualityHintDismissed)
        let langCode = appState.selectedLanguage == "de" ? "de-DE" : "en-US"
        showVoiceQualityHint = !dismissed && SpeechService.onlyDefaultQualityAvailable(for: langCode)
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
        BriefingNarrator.timeOfDay(language: appState.selectedLanguage).greeting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(1)
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(SunwakeTypography.hero)
                }
                Spacer()
                DayProgressRing(accentColor: appState.accentColor)
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(appState.selectedLanguage == "de" ? "Briefing wird vorbereitet…" : "Preparing your briefing…")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !summary.isEmpty {
                Button {
                    HapticFeedback.selection()
                    onSummaryTap?()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(summary)
                            .font(SunwakeTypography.callout)
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
    var language: String = "en"

    private var timeString: String {
        if event.isAllDay { return language == "de" ? "Ganztägig" : "All day" }
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
                    .font(SunwakeTypography.callout.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(timeString)
                        .font(SunwakeTypography.caption)
                }
                .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(SunwakeTypography.caption)
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
                            .font(SunwakeTypography.caption2.weight(.semibold))
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
    /// The AI-generated briefing from TodayViewModel; empty while generating
    /// or when generation is unavailable.
    let aiSummary: String
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let weather: WeatherData?
    let language: String
    let accentColor: Color
    let accentColorHex: String

    /// The exact text that gets spoken: the AI briefing when it exists,
    /// otherwise the rule-based narrator template.
    private var spokenText: String {
        aiSummary.isEmpty
            ? BriefingNarrator.narrative(events: events, reminders: reminders, weather: weather, language: language)
            : aiSummary
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if speechService.isPlaying {
                    Text(speechService.currentItemTitle)
                        .font(SunwakeTypography.caption.weight(.semibold))
                        .lineLimit(1)
                    ProgressView(value: speechService.progress)
                        .tint(accentColor)
                } else {
                    Text(language == "de" ? "Briefing abspielen" : "Play briefing")
                        .font(SunwakeTypography.callout.weight(.semibold))
                    Text(language == "de" ? "Tippe, um deinen Tag zu hören" : "Tap to hear your day read aloud")
                        .font(SunwakeTypography.caption)
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
                        let item = SpeechItem(
                            title: "Briefing",
                            text: spokenText,
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
}

// MARK: — Voice quality hint

/// Small banner above the play bar, shown while only the robotic
/// default-quality system voice is installed. Tapping opens the voice
/// settings, which explain how to download a natural Enhanced/Premium voice.
struct VoiceQualityHintBanner: View {
    let language: String
    let accentColor: Color
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(language == "de" ? "Natürlichere Stimme verfügbar" : "A more natural voice is available")
                            .font(SunwakeTypography.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(language == "de" ? "Einmalig kostenlos laden — tippe hier" : "Free one-time download — tap here")
                            .font(SunwakeTypography.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: — Tomorrow preview (Premium)

struct TomorrowPreviewCard: View {
    let isPremium: Bool
    let isLoading: Bool
    let hasLoaded: Bool
    let summary: String
    let events: [CalendarEvent]
    let language: String
    let accentColor: Color
    let onUnlock: () -> Void
    let onLoad: () -> Void

    private var isDE: Bool { language == "de" }

    private var tomorrowTitle: String {
        isDE ? "Ausblick auf morgen" : "Tomorrow's outlook"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tomorrowTitle, systemImage: "moon.stars.fill")
                    .font(SunwakeTypography.headline)
                Spacer()
                if !isPremium {
                    Text("Premium")
                        .font(SunwakeTypography.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor))
                }
            }

            if !isPremium {
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text(isDE
                             ? "Mit Premium siehst du schon heute, was morgen ansteht."
                             : "With Premium, see tonight what tomorrow holds.")
                            .font(SunwakeTypography.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(isDE ? "Morgen wird vorbereitet…" : "Preparing tomorrow…")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else if hasLoaded {
                if !summary.isEmpty {
                    Text(summary)
                        .font(SunwakeTypography.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(events) { event in
                    HStack(spacing: 10) {
                        Text(timeLabel(for: event))
                            .font(SunwakeTypography.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(accentColor)
                            .frame(width: 64, alignment: .leading)
                        Text(event.title)
                            .font(SunwakeTypography.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Button(action: onLoad) {
                    Label(isDE ? "Aktualisieren" : "Refresh", systemImage: "arrow.clockwise")
                        .font(SunwakeTypography.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onLoad) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(isDE ? "Vorschau erstellen" : "Generate preview")
                            .font(SunwakeTypography.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(accentColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func timeLabel(for event: CalendarEvent) -> String {
        if event.isAllDay { return isDE ? "Ganztägig" : "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: event.startDate)
    }
}

// MARK: — Empty state

struct EmptyDayView: View {
    let accentColor: Color
    let language: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(accentColor)
            Text(language == "de" ? "Entspannter Tag" : "Clear day ahead")
                .font(SunwakeTypography.title3)
            Text(language == "de" ? "Keine Termine heute. Genieß die freie Zeit." : "No events scheduled for today. Enjoy the open time.")
                .font(SunwakeTypography.body)
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
                .font(SunwakeTypography.headline)
            Spacer()
            Text("\(count)")
                .font(SunwakeTypography.caption.weight(.semibold))
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
    let language: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: weather.sfSymbol)
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.conditionLabel(language: language))
                    .font(SunwakeTypography.callout.weight(.semibold))
                HStack(spacing: 8) {
                    Text("↑\(Int(weather.temperatureMax.rounded()))°")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                    Text("↓\(Int(weather.temperatureMin.rounded()))°")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                    if weather.windSpeed > 0 {
                        Text("· \(Int(weather.windSpeed.rounded())) km/h")
                            .font(SunwakeTypography.caption)
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
        guard let due = reminder.dueDate, !reminder.isDueTomorrow else { return nil }
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
                            .font(SunwakeTypography.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    Text(reminder.title)
                        .font(SunwakeTypography.callout)
                        .lineLimit(2)
                }

                if reminder.isDueTomorrow {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.clock")
                            .font(.caption2)
                        Text("Bis morgen", comment: "Reminder due tomorrow label")
                            .font(SunwakeTypography.caption)
                    }
                    .foregroundStyle(.orange)
                } else if let time = timeString {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(time)
                            .font(SunwakeTypography.caption)
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

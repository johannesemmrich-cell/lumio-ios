import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    @StateObject private var speechService = SpeechService()

    @State private var showPaywall = false
    @State private var showCalendar = false
    @State private var headerOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        TodayHeaderView(
                            summary: viewModel.aiSummary,
                            isGenerating: viewModel.isGeneratingAI
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        if viewModel.events.isEmpty && !viewModel.isLoadingEvents {
                            EmptyDayView()
                                .padding(.horizontal, 20)
                        } else {
                            eventsSection
                                .padding(.horizontal, 20)
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

                PlayBarView(speechService: speechService, events: viewModel.events, language: appState.selectedLanguage)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.08), radius: 20, y: -4)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button {
                            showCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoadingEvents)
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
            .task {
                viewModel.language = appState.selectedLanguage
                viewModel.briefingLength = appState.briefingLength
                viewModel.briefingStyle = appState.briefingStyle
                await viewModel.loadInitialData()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Today's Events", count: viewModel.events.count)
                .padding(.bottom, 4)

            ForEach(viewModel.events) { event in
                EventCard(event: event)
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

// MARK: — Header

struct TodayHeaderView: View {
    let summary: String
    let isGenerating: Bool

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
                DayProgressRing()
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
                Text(summary)
                    .font(LumioTypography.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

struct DayProgressRing: View {
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
                .stroke(Color.lumioAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
    let language: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                if speechService.isPlaying {
                    Text(speechService.currentItemTitle)
                        .font(LumioTypography.caption.weight(.semibold))
                        .lineLimit(1)
                    ProgressView(value: speechService.progress)
                        .tint(Color.lumioAccent)
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
                        speechService.skipBackward()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.body.weight(.medium))
                    }
                }

                Button {
                    if speechService.isPlaying {
                        speechService.pause()
                    } else if speechService.isPaused {
                        speechService.resume()
                    } else {
                        let items = events.map { event in
                            SpeechItem(
                                title: event.title,
                                text: buildSpeechText(for: event),
                                language: language == "de" ? "de-DE" : "en-US"
                            )
                        }
                        speechService.speak(items)
                    }
                } label: {
                    Image(systemName: speechService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.lumioAccent)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }

                if speechService.isPlaying || speechService.isPaused {
                    Button {
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

    private func buildSpeechText(for event: CalendarEvent) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        if event.isAllDay {
            return "\(event.title). All day event."
        }
        return "\(event.title), at \(fmt.string(from: event.startDate))."
    }
}

// MARK: — Empty state

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.lumioAccent)
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

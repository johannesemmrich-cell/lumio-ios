import SwiftUI
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var weather: WeatherData?
    @Published private(set) var aiSummary: String = ""
    @Published private(set) var isLoadingEvents: Bool = false
    @Published private(set) var isGeneratingAI: Bool = false
    @Published private(set) var error: String?

    // Premium "tomorrow preview" — generated on demand, never automatically.
    @Published private(set) var tomorrowEvents: [CalendarEvent] = []
    @Published private(set) var tomorrowReminders: [ReminderItem] = []
    @Published private(set) var tomorrowSummary: String = ""
    @Published private(set) var isLoadingTomorrow: Bool = false
    @Published private(set) var hasLoadedTomorrow: Bool = false

    var language: String = "en"
    var briefingLength: BriefingLength = .medium
    var briefingStyle: BriefingStyle = .friendly

    /// Whether the most recent summary was generated with weather data —
    /// late-arriving weather triggers at most one regeneration.
    private var summaryHadWeather = false

    private let calendarService = CalendarService()
    private let aiService = AIService()
    let weatherService = WeatherService()

    func loadInitialData() async {
        await fetchEvents()
        await generateSummaryIncludingWeather()
    }

    func refresh() async {
        await fetchEvents()
        await generateSummaryIncludingWeather()
    }

    /// Set once the in-flight weather fetch completes (success or failure) —
    /// lets the bounded wait below exit early.
    private var weatherFetchFinished = false

    /// Gives the weather fetch a short head start (max 2.5 s) so the first
    /// summary usually already contains it, then generates. If the weather
    /// only arrives later, the summary is regenerated exactly once.
    /// `weatherTask.value` is not cancellation-interruptible and a task group
    /// awaits all remaining children at scope exit, so a group "race" cannot
    /// enforce the cap — hence the bounded poll.
    private func generateSummaryIncludingWeather() async {
        weatherFetchFinished = false
        let weatherTask = Task { [weak self] in
            await self?.fetchWeather()
            self?.weatherFetchFinished = true
        }

        let deadline = ContinuousClock.now.advanced(by: .seconds(2.5))
        while !weatherFetchFinished && ContinuousClock.now < deadline {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        await generateSummary()

        // Late weather: regenerate once so the briefing includes it.
        Task { [weak self] in
            await weatherTask.value
            guard let self else { return }
            if self.weather != nil && !self.summaryHadWeather {
                await self.generateSummary()
            }
        }
    }

    private func fetchEvents() async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }

        let granted = await calendarService.requestAccess()
        if granted {
            await calendarService.fetchTodayEvents()
            let excluded = BriefingExclusionStore.excludedIDs
            events = calendarService.todayEvents.filter { !excluded.contains($0.calendarIdentifier) }
        }

        _ = await calendarService.requestRemindersAccess()
        reminders = calendarService.todayReminders
    }

    private func fetchWeather() async {
        await weatherService.fetchWeather()
        weather = weatherService.weather
    }

    /// Builds the premium look-ahead at tomorrow: its own event/reminder fetch
    /// (without touching today's published lists) plus the day-2 forecast that
    /// fetchWeather() already delivers.
    func loadTomorrowPreview() async {
        guard !isLoadingTomorrow else { return }
        isLoadingTomorrow = true
        defer { isLoadingTomorrow = false }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let excluded = BriefingExclusionStore.excludedIDs
        tomorrowEvents = await calendarService.events(on: tomorrow)
            .filter { !excluded.contains($0.calendarIdentifier) }
        tomorrowReminders = await calendarService.reminders(dueOn: tomorrow)

        if weather == nil {
            await fetchWeather()
        }

        tomorrowSummary = await aiService.summarizeTomorrowBriefing(
            events: tomorrowEvents,
            reminders: tomorrowReminders,
            weather: weather,
            language: language,
            length: briefingLength,
            style: briefingStyle
        )
        hasLoadedTomorrow = true
    }

    private func generateSummary() async {
        isGeneratingAI = true
        defer { isGeneratingAI = false }
        summaryHadWeather = weather != nil
        aiSummary = await aiService.summarizeBriefing(
            events: events,
            reminders: reminders,
            weather: weather,
            pdfTexts: [],
            language: language,
            length: briefingLength,
            style: briefingStyle
        )
    }
}

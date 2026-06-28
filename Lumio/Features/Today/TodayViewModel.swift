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

    var language: String = "en"
    var briefingLength: BriefingLength = .medium
    var briefingStyle: BriefingStyle = .friendly

    private let calendarService = CalendarService()
    private let aiService = AIService()
    let weatherService = WeatherService()

    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchEvents() }
            group.addTask { await self.fetchWeather() }
        }
        await generateSummary()
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchEvents() }
            group.addTask { await self.fetchWeather() }
        }
        await generateSummary()
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

        await calendarService.requestRemindersAccess()
        reminders = calendarService.todayReminders
    }

    private func fetchWeather() async {
        await weatherService.fetchWeather()
        weather = weatherService.weather
    }

    private func generateSummary() async {
        isGeneratingAI = true
        defer { isGeneratingAI = false }
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

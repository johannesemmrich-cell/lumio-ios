import SwiftUI
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var aiSummary: String = ""
    @Published private(set) var isLoadingEvents: Bool = false
    @Published private(set) var isGeneratingAI: Bool = false
    @Published private(set) var error: String?

    private let calendarService = CalendarService()
    private let aiService = AIService()

    func loadInitialData() async {
        await fetchEvents()
        await generateSummary()
    }

    func refresh() async {
        await fetchEvents()
        await generateSummary()
    }

    private func fetchEvents() async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }

        let status = await calendarService.requestAccess()
        if status {
            await calendarService.fetchTodayEvents()
            let excluded = BriefingExclusionStore.excludedIDs
            events = calendarService.todayEvents.filter { !excluded.contains($0.calendarIdentifier) }
        }
    }

    private func generateSummary() async {
        guard !events.isEmpty else { return }
        isGeneratingAI = true
        defer { isGeneratingAI = false }
        aiSummary = await aiService.summarizeBriefing(events: events, pdfTexts: [])
    }
}

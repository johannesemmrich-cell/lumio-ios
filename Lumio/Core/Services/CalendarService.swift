import EventKit
import Foundation

// MARK: — Calendar Provider

enum CalendarProvider: String, CaseIterable, Identifiable {
    case apple   = "Apple"
    case google  = "Google"
    case outlook = "Outlook"
    case other   = "Andere"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .apple:   return "applelogo"
        case .google:  return "globe"
        case .outlook: return "envelope.fill"
        case .other:   return "calendar"
        }
    }
}

extension EKCalendar {
    var provider: CalendarProvider {
        switch source.sourceType {
        case .local, .mobileMe:
            return .apple
        case .calDAV:
            let t = source.title.lowercased()
            if t.contains("icloud") || t.contains("apple") { return .apple }
            if t.contains("google") || t.contains("gmail") { return .google }
            return .other
        case .exchange:
            return .outlook
        default:
            return .other
        }
    }
}

// MARK: — Briefing Exclusion Store

struct BriefingExclusionStore {
    private static let key = "briefingExcludedCalendarIDs"

    static var excludedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    static func toggle(_ calendarID: String) {
        var ids = excludedIDs
        if ids.contains(calendarID) { ids.remove(calendarID) } else { ids.insert(calendarID) }
        excludedIDs = ids
    }

    static func isExcluded(_ calendarID: String) -> Bool {
        excludedIDs.contains(calendarID)
    }
}

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarColor: CGColor
    let calendarTitle: String
    let calendarIdentifier: String
    let source: CalendarSource
}

enum CalendarSource: String, Codable {
    case apple = "apple"
    case outlook = "outlook"
    case google = "google"
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var isLoading: Bool = false

    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if granted { await fetchTodayEvents() }
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    func fetchTodayEvents() async {
        await fetchEvents(for: Date())
    }

    func fetchEvents(for date: Date) async {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        todayEvents = ekEvents
            .sorted { $0.startDate < $1.startDate }
            .map { CalendarEvent(from: $0) }
    }

    func addEvent(title: String, startDate: Date, endDate: Date, calendarIdentifier: String? = nil) async throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CalendarError.accessDenied
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        if let id = calendarIdentifier, let cal = store.calendar(withIdentifier: id) {
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }
        try store.save(event, span: .thisEvent)
        await fetchTodayEvents()
    }

    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied: return String(localized: "Calendar access is required.")
        case .eventNotFound: return String(localized: "The event could not be found.")
        }
    }
}

private extension CalendarEvent {
    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? String(localized: "Untitled Event")
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location
        self.notes = event.notes
        self.calendarColor = event.calendar.cgColor
        self.calendarTitle = event.calendar.title
        self.calendarIdentifier = event.calendar.calendarIdentifier
        self.source = .apple
    }
}

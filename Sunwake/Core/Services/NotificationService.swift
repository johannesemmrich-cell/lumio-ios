import UserNotifications
import Foundation

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    private init() {}

    private static let identifierPrefix = "briefing-weekday-"

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // Schedule notifications — each weekday can have its own time.
    // dayTimes: [weekday: (hour, minute)], Calendar weekday: 1=Sun…7=Sat
    func scheduleBriefings(dayTimes: [Int: (hour: Int, minute: Int)], previewText: String) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !dayTimes.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Good morning ☀️")
        content.body = previewText
        content.sound = .default
        content.categoryIdentifier = "DAILY_BRIEFING"

        for (weekday, time) in dayTimes {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = time.hour
            components.minute = time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)\(weekday)",
                content: content,
                trigger: trigger
            )
            do { try await center.add(request) } catch {
                print("Failed to schedule notification for weekday \(weekday): \(error)")
            }
        }
    }

    // Legacy — kept for callers that haven't migrated yet
    func scheduleBriefings(days: Set<Int>, hour: Int, minute: Int, previewText: String) async {
        let times = Dictionary(uniqueKeysWithValues: days.map { ($0, (hour: hour, minute: minute)) })
        await scheduleBriefings(dayTimes: times, previewText: previewText)
    }

    func scheduleDailyBriefing(at hour: Int, minute: Int, previewText: String) async {
        await scheduleBriefings(days: Set(2...6), hour: hour, minute: minute, previewText: previewText)
    }

    func buildPreviewText(from events: [CalendarEvent]) -> String {
        let topEvents = events.prefix(3)
        if topEvents.isEmpty {
            return String(localized: "No events today — tap for your full briefing.")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let lines = topEvents.map { "\(formatter.string(from: $0.startDate)) \($0.title)" }
        return lines.joined(separator: " · ")
    }
}

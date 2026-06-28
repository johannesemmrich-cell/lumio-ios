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

    // Schedule notifications for selected weekdays (Calendar weekday: 1=Sun…7=Sat)
    func scheduleBriefings(days: Set<Int>, hour: Int, minute: Int, previewText: String) async {
        let center = UNUserNotificationCenter.current()

        // Remove all existing briefing notifications
        let allIDs = (1...7).map { "\(Self.identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        guard !days.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Good morning ☀️")
        content.body = previewText
        content.sound = .default
        content.categoryIdentifier = "DAILY_BRIEFING"

        for weekday in days {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)\(weekday)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification for weekday \(weekday): \(error)")
            }
        }
    }

    // Legacy single-time scheduling (kept for backward compat)
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

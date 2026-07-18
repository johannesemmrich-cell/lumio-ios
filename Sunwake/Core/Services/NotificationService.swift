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
    // language: the in-app language choice — String(localized:) would follow
    // the device language instead and mismatch the rest of the app.
    func scheduleBriefings(dayTimes: [Int: (hour: Int, minute: Int)], previewText: String, language: String) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !dayTimes.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = language == "de" ? "Guten Morgen ☀️" : "Good morning ☀️"
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

    func buildPreviewText(from events: [CalendarEvent], language: String) -> String {
        let topEvents = events.prefix(3)
        if topEvents.isEmpty {
            return language == "de"
                ? "Heute keine Termine — tippe für dein volles Briefing."
                : "No events today — tap for your full briefing."
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let lines = topEvents.map { "\(formatter.string(from: $0.startDate)) \($0.title)" }
        return lines.joined(separator: " · ")
    }
}

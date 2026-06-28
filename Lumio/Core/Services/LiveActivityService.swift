import ActivityKit
import Foundation

// MARK: — Activity Attributes (shared between app and Dynamic Island)

struct LumioBriefingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentItemTitle: String
        var currentItemTime: String
        var nextItemTitle: String?
        var nextItemTime: String?
        var isPlaying: Bool
        var progress: Double
        var totalItems: Int
        var currentIndex: Int
    }

    var briefingDate: Date
    var totalEvents: Int
    var accentColorHex: String
}

// MARK: — Live Activity Service

final class LiveActivityService: ObservableObject, @unchecked Sendable {
    @Published private(set) var isActivityActive: Bool = false

    private var currentActivity: Activity<LumioBriefingAttributes>?

    init() {
        // Terminate any orphaned activities left from a previous app session
        Task {
            for activity in Activity<LumioBriefingAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    @MainActor func startActivity(totalEvents: Int, firstEvent: String, firstTime: String, accentColorHex: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = LumioBriefingAttributes(
            briefingDate: Calendar.current.startOfDay(for: Date()),
            totalEvents: totalEvents,
            accentColorHex: accentColorHex
        )
        let state = LumioBriefingAttributes.ContentState(
            currentItemTitle: firstEvent,
            currentItemTime: firstTime,
            nextItemTitle: nil,
            nextItemTime: nil,
            isPlaying: true,
            progress: 0,
            totalItems: totalEvents,
            currentIndex: 0
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(180))
            )
            isActivityActive = true
        } catch {
            print("LiveActivity start failed: \(error)")
        }
    }

    func update(currentTitle: String, currentTime: String, nextTitle: String?, nextTime: String?, isPlaying: Bool, progress: Double, index: Int) async {
        guard let activity = currentActivity else { return }
        let totalEvents = activity.attributes.totalEvents
        let state = LumioBriefingAttributes.ContentState(
            currentItemTitle: currentTitle,
            currentItemTime: currentTime,
            nextItemTitle: nextTitle,
            nextItemTime: nextTime,
            isPlaying: isPlaying,
            progress: progress,
            totalItems: totalEvents,
            currentIndex: index
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(180))
        // Hop to a detached task so Activity (non-Sendable in some SDK builds) isn't crossing isolation
        let captured = activity
        await Task.detached { await captured.update(content) }.value
    }

    func stop() async {
        let captured = currentActivity
        currentActivity = nil
        isActivityActive = false
        if let captured {
            await Task.detached { await captured.end(nil, dismissalPolicy: .immediate) }.value
        }
    }
}

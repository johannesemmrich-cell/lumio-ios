import SwiftUI
import SwiftData
import ActivityKit

@main
struct LumioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    /// Single app-wide speech pipeline: exactly one MPRemoteCommandCenter
    /// registration and one LiveActivityService, so lock-screen controls
    /// always drive the audio that is actually playing.
    @StateObject private var speechService = SpeechService()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PDFFolder.self,
            PDFDocument.self,
            FeedbackEntry.self,
            UserPreferences.self,
            BriefingCache.self,
            DevTodoItem.self,
            CalendarEventNote.self,
        ])
        // Try CloudKit sync first; fall back to local-only (e.g. Simulator without entitlements)
        let cloudConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .environmentObject(speechService)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .environment(\.locale, appState.locale)
                .tint(appState.accentColor)
                .task { await endStaleLiveActivities() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await endStaleLiveActivities() }
                    }
                }
        }
    }

    private func endStaleLiveActivities() async {
        for activity in Activity<LumioBriefingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

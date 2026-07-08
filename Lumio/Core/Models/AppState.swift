import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var selectedTab: AppTab = .today
    @Published var isDeveloperModeActive: Bool
    @Published var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: UserDefaultsKey.selectedLanguage) }
    }
    @Published var tabOrder: [AppTab] {
        didSet { UserDefaults.standard.set(tabOrder.map(\.rawValue), forKey: UserDefaultsKey.tabOrder) }
    }
    @Published var briefingLength: BriefingLength {
        didSet { UserDefaults.standard.set(briefingLength.rawValue, forKey: UserDefaultsKey.briefingLength) }
    }
    @Published var briefingStyle: BriefingStyle {
        didSet { UserDefaults.standard.set(briefingStyle.rawValue, forKey: UserDefaultsKey.briefingStyle) }
    }
    @Published var accentColorHex: String {
        didSet { UserDefaults.standard.set(accentColorHex, forKey: UserDefaultsKey.accentColorHex) }
    }
    @Published var topBarActions: [String] {
        didSet { UserDefaults.standard.set(topBarActions, forKey: UserDefaultsKey.topBarActions) }
    }
    @Published var pendingBriefingForChat: String?

    var accentColor: Color { Color(hex: accentColorHex) }

    var locale: Locale { Locale(identifier: selectedLanguage) }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.hasCompletedOnboarding)
        self.isDeveloperModeActive = UserDefaults.standard.bool(forKey: UserDefaultsKey.developerModeActive)
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedLanguage)
        self.selectedLanguage = saved ?? (Locale.current.language.languageCode?.identifier == "de" ? "de" : "en")

        let savedTopBar = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.topBarActions) ?? ["chat_shortcut", "refresh"]
        self.topBarActions = savedTopBar

        if let savedOrder = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.tabOrder) {
            var ordered = savedOrder.compactMap { AppTab(rawValue: $0) }
            // Remove any tab that is already shown in the top bar to prevent duplicates
            if savedTopBar.contains("calendar") { ordered.removeAll { $0 == .calendar } }
            if savedTopBar.contains("chat_shortcut") { ordered.removeAll { $0 == .chat } }
            // Settings must always be in the tab bar
            if !ordered.contains(.settings) { ordered.append(.settings) }
            self.tabOrder = Array(ordered.prefix(4))
        } else {
            self.tabOrder = [.today, .library, .calendar, .settings]
        }

        self.briefingLength = BriefingLength(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.briefingLength) ?? "") ?? .medium
        self.briefingStyle = BriefingStyle(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.briefingStyle) ?? "") ?? .friendly
        self.accentColorHex = UserDefaults.standard.string(forKey: UserDefaultsKey.accentColorHex) ?? "FF9500"
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasCompletedOnboarding)
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }

    // Called once when the user first becomes premium.
    // Swaps chat (top bar) ↔ calendar (tab bar) to the premium arrangement.
    func applyPremiumLayoutMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasMigratedPremiumLayout) else { return }
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasMigratedPremiumLayout)

        let chatInTopBar = topBarActions.contains("chat_shortcut")
        let chatInTab = tabOrder.contains(.chat)
        let calendarInTab = tabOrder.contains(.calendar)

        guard chatInTopBar && !chatInTab && calendarInTab else { return }

        var newTabs = tabOrder
        var newTop = topBarActions

        if let calIdx = newTabs.firstIndex(of: .calendar) { newTabs[calIdx] = .chat }
        if let topIdx = newTop.firstIndex(of: "chat_shortcut") { newTop[topIdx] = "calendar" }

        withAnimation(.spring(duration: 0.3)) {
            tabOrder = newTabs
            topBarActions = newTop
        }
    }
}

enum AppTab: String, CaseIterable {
    case today = "today"
    case calendar = "calendar"
    case library = "library"
    case chat = "chat"
    case settings = "settings"

    var title: LocalizedStringKey {
        switch self {
        case .today:    return "Today"
        case .calendar: return "Kalender"
        case .library:  return "Library"
        case .chat:     return "Chat"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today:    return "sun.horizon.fill"
        case .calendar: return "calendar"
        case .library:  return "books.vertical.fill"
        case .chat:     return "bubble.left.and.bubble.right.fill"
        case .settings: return "gearshape.fill"
        }
    }

}

enum UserDefaultsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let selectedLanguage = "selectedLanguage"
    static let notificationTime = "notificationTime"
    static let developerModeActive = "developerModeActive"
    static let selectedTheme = "selectedTheme"
    static let connectedCalendars = "connectedCalendars"
    static let tabOrder = "tabOrder"
    static let briefingLength = "briefingLength"
    static let briefingStyle = "briefingStyle"
    static let accentColorHex = "accentColorHex"
    static let topBarActions = "topBarActions"
    static let briefingScheduleDays = "briefingScheduleDays"
    static let briefingScheduleHour = "briefingScheduleHour"
    static let briefingScheduleMinute = "briefingScheduleMinute"
    static let hasMigratedPremiumLayout = "hasMigratedPremiumLayout"
    // Per-day times: "briefingHour_<weekday>" / "briefingMinute_<weekday>"
    static func briefingHourKey(_ weekday: Int) -> String { "briefingHour_\(weekday)" }
    static func briefingMinuteKey(_ weekday: Int) -> String { "briefingMinute_\(weekday)" }
}

// MARK: — Briefing Settings

enum BriefingLength: String, CaseIterable {
    case short  = "short"
    case medium = "medium"
    case long   = "long"

    var displayName: LocalizedStringKey {
        switch self {
        case .short:  return "Kurz"
        case .medium: return "Mittel"
        case .long:   return "Lang"
        }
    }

    var maxSentences: Int {
        switch self {
        case .short:  return 1
        case .medium: return 3
        case .long:   return 5
        }
    }
}

enum BriefingStyle: String, CaseIterable {
    case friendly = "friendly"
    case formal   = "formal"
    case concise  = "concise"

    var displayName: LocalizedStringKey {
        switch self {
        case .friendly: return "Freundlich"
        case .formal:   return "Formell"
        case .concise:  return "Knapp"
        }
    }
}

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
    @Published var tabIconColorHexes: [String: String] {
        didSet {
            UserDefaults.standard.set(tabIconColorHexes, forKey: UserDefaultsKey.tabIconColorHexes)
        }
    }

    var accentColor: Color { Color(hex: accentColorHex) }

    func iconColor(for tab: AppTab) -> Color {
        if let hex = tabIconColorHexes[tab.rawValue] { return Color(hex: hex) }
        return accentColor
    }

    func setIconColor(_ color: Color, for tab: AppTab) {
        tabIconColorHexes[tab.rawValue] = color.hexString
    }

    var locale: Locale { Locale(identifier: selectedLanguage) }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.hasCompletedOnboarding)
        self.isDeveloperModeActive = UserDefaults.standard.bool(forKey: UserDefaultsKey.developerModeActive)
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedLanguage)
        self.selectedLanguage = saved ?? (Locale.current.language.languageCode?.identifier == "de" ? "de" : "en")

        if let savedOrder = UserDefaults.standard.stringArray(forKey: UserDefaultsKey.tabOrder) {
            let ordered = savedOrder.compactMap { AppTab(rawValue: $0) }
            let missing = AppTab.allCases.filter { !ordered.contains($0) }
            self.tabOrder = ordered + missing
        } else {
            self.tabOrder = AppTab.allCases
        }

        self.briefingLength = BriefingLength(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.briefingLength) ?? "") ?? .medium
        self.briefingStyle = BriefingStyle(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.briefingStyle) ?? "") ?? .friendly
        self.accentColorHex = UserDefaults.standard.string(forKey: UserDefaultsKey.accentColorHex) ?? "FF9500"
        self.tabIconColorHexes = (UserDefaults.standard.dictionary(forKey: UserDefaultsKey.tabIconColorHexes) as? [String: String]) ?? [:]
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasCompletedOnboarding)
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

enum AppTab: String, CaseIterable {
    case today = "today"
    case library = "library"
    case chat = "chat"
    case settings = "settings"

    var title: LocalizedStringKey {
        switch self {
        case .today: return "Today"
        case .library: return "Library"
        case .chat: return "Chat"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .library: return "books.vertical.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
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
    static let tabIconColorHexes = "tabIconColorHexes"
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

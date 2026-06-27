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

    var locale: Locale { Locale(identifier: selectedLanguage) }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.hasCompletedOnboarding)
        self.isDeveloperModeActive = UserDefaults.standard.bool(forKey: UserDefaultsKey.developerModeActive)
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedLanguage)
        self.selectedLanguage = saved ?? (Locale.current.language.languageCode?.identifier == "de" ? "de" : "en")
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
    static let developerModePassword = "developerModePassword"
    static let hasSetDeveloperPassword = "hasSetDeveloperPassword"
    static let selectedTheme = "selectedTheme"
    static let connectedCalendars = "connectedCalendars"
}

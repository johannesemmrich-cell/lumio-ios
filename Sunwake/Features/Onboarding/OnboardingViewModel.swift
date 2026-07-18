import SwiftUI
import Combine

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case language = 1
    case calendar = 2
    case notifications = 3
    case pdfUpload = 4
    case premium = 5
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var selectedLanguage: String = Locale.current.language.languageCode?.identifier == "de" ? "de" : "en"
    @Published var calendarConnected: Bool = false
    @Published var notificationsEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let calendarService = CalendarService()

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = next
        }
    }

    func connectAppleCalendar() async {
        isLoading = true
        defer { isLoading = false }
        let granted = await calendarService.requestAccess()
        calendarConnected = granted
        if granted { advance() }
        else {
            errorMessage = selectedLanguage == "de"
                ? "Kalenderzugriff wurde abgelehnt. Du kannst das in den Einstellungen ändern."
                : "Calendar access was denied. You can change this in Settings."
        }
    }

    func requestNotifications() async {
        isLoading = true
        defer { isLoading = false }
        let granted = await NotificationService.shared.requestPermission()
        notificationsEnabled = granted
        advance()
    }

    func setLanguage(_ code: String, appState: AppState) {
        selectedLanguage = code
        appState.selectedLanguage = code
    }

    func completeOnboarding(appState: AppState) {
        appState.selectedLanguage = selectedLanguage
        appState.completeOnboarding()
    }
}

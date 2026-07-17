import SwiftUI
import SwiftData
import EventKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var versionTapCount = 0
    @State private var showDeveloperUnlock = false
    @State private var showPaywall = false
    @State private var showResetOnboardingConfirm = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            List {
                // Calendar & Reminders
                Section(loc("Kalender", "Calendar")) {
                    NavigationLink(destination: CalendarSettingsView()) {
                        Label(loc("Verbundene Kalender", "Connected Calendars"), systemImage: "calendar")
                    }
                    NavigationLink(destination: ReminderSettingsView()) {
                        Label(loc("Erinnerungen", "Reminders"), systemImage: "checklist")
                    }
                }

                // Notifications
                Section(loc("Mitteilungen", "Notifications")) {
                    NavigationLink(destination: BriefingScheduleView()) {
                        // "bell.badge.clock" does not exist as an SF Symbol (renders blank)
                        Label(loc("Briefing-Zeitplan", "Briefing schedule"), systemImage: "calendar.badge.clock")
                    }
                }

                // Voice
                Section(loc("Vorlesen", "Read aloud")) {
                    NavigationLink(destination: VoiceSettingsView()) {
                        Label(loc("Stimme", "Voice"), systemImage: "waveform")
                    }
                }

                // Appearance
                Section(loc("Darstellung", "Appearance")) {
                    ThemePickerRow(themeManager: themeManager)
                }

                // Subscription
                Section(loc("Abo", "Subscription")) {
                    if subscriptionManager.effectivelyPremium {
                        Label(loc("Premium aktiv", "Premium Active"), systemImage: "star.fill")
                            .foregroundStyle(appState.accentColor)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label(loc("Auf Premium upgraden", "Upgrade to Premium"), systemImage: "star")
                                Spacer()
                                Text(loc("2 €/Monat", "€2/mo"))
                                    .font(SunwakeTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button(loc("Käufe wiederherstellen", "Restore Purchases")) {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .foregroundStyle(.secondary)
                }

                // Premium customization
                if subscriptionManager.effectivelyPremium {
                    Section("Premium") {
                        NavigationLink(destination: BriefingSettingsView()) {
                            // "waveform.and.sparkles" does not exist as an SF Symbol (renders blank)
                            Label(loc("Briefing einstellen", "Briefing settings"), systemImage: "wand.and.sparkles")
                        }
                        NavigationLink(destination: AppLayoutConfigView()) {
                            Label(loc("App-Layout & Farben", "App layout & colors"), systemImage: "paintpalette.fill")
                        }
                        NavigationLink(destination: AppIconPickerView()) {
                            Label(loc("App-Icon", "App icon"), systemImage: "app.badge")
                        }
                    }
                }

                // About
                Section(loc("Über", "About")) {
                    NavigationLink(destination: AboutView()) {
                        Label(loc("Über Sunwake", "About Sunwake"), systemImage: "info.circle")
                    }
                    NavigationLink(destination: PrivacyView()) {
                        Label(loc("Datenschutz", "Privacy"), systemImage: "hand.raised")
                    }
                    Button {
                        showResetOnboardingConfirm = true
                    } label: {
                        Label(loc("Onboarding wiederholen", "Repeat onboarding"), systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.primary)
                    }
                }

                // Developer Mode entry (hidden)
                Section {
                    Button {
                        handleVersionTap()
                    } label: {
                        HStack {
                            Text("Version \(appVersion) (\(buildNumber))")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if appState.isDeveloperModeActive {
                                Text("DEV")
                                    .font(SunwakeTypography.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if appState.isDeveloperModeActive {
                    Section("Developer") {
                        NavigationLink(destination: DeveloperModeView()) {
                            Label("Developer Mode", systemImage: "hammer.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tint(appState.accentColor)
            .toolbar {
                if appState.isDeveloperModeActive {
                    ToolbarItem(placement: .topBarLeading) {
                        DeveloperFeedbackButton(screen: "Settings", feature: "General", element: "Toolbar")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .tint(appState.accentColor)
        .sheet(isPresented: $showDeveloperUnlock) {
            DeveloperUnlockSheet(isPresented: $showDeveloperUnlock)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog(
            "Onboarding wiederholen?",
            isPresented: $showResetOnboardingConfirm,
            titleVisibility: .visible
        ) {
            Button("Onboarding starten", role: .destructive) {
                resetOnboarding()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die App startet das Onboarding erneut. Deine Daten bleiben erhalten.")
        }
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.hasCompletedOnboarding)
        withAnimation(.easeInOut(duration: 0.5)) {
            appState.hasCompletedOnboarding = false
        }
    }

    private func handleVersionTap() {
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            showDeveloperUnlock = true
        }
    }
}

// MARK: — Theme Picker Row

struct ThemePickerRow: View {
    @ObservedObject var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack {
            Label(loc("Design", "Theme"), systemImage: "paintbrush")
            Spacer()
            Picker(loc("Design", "Theme"), selection: $themeManager.currentTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName(language: appState.selectedLanguage)).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}

// MARK: — Calendar Settings

struct CalendarSettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @State private var availableCalendars: [EKCalendar] = []
    @State private var excludedIDs: Set<String> = BriefingExclusionStore.excludedIDs

    private var calendarsByProvider: [(CalendarProvider, [EKCalendar])] {
        CalendarProvider.allCases.compactMap { provider in
            let cals = availableCalendars.filter { $0.provider == provider }
            return cals.isEmpty ? nil : (provider, cals)
        }
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        List {
            // Connected providers
            Section {
                CalendarProviderButton(name: "Apple Calendar", icon: "applelogo", color: .primary, isLoading: false) {}
                CalendarProviderButton(name: "Google Calendar", icon: "globe", color: .blue, isLoading: false, badge: loc("Bald verfügbar", "Coming soon")) {}
                CalendarProviderButton(name: "Outlook", icon: "envelope.fill", color: .blue, isLoading: false, badge: loc("Bald verfügbar", "Coming soon")) {}
            } header: {
                Text(loc("Verbundene Anbieter", "Connected providers"))
            } footer: {
                if !subscriptionManager.effectivelyPremium {
                    Text(loc("Free plan: 1 Kalender. Mit Premium mehrere Anbieter verbinden.", "Free plan: 1 calendar. Connect multiple providers with Premium."))
                        .font(SunwakeTypography.caption)
                }
            }

            // Briefing inclusion per calendar
            if !availableCalendars.isEmpty {
                ForEach(calendarsByProvider, id: \.0.id) { provider, cals in
                    Section {
                        ForEach(cals, id: \.calendarIdentifier) { cal in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(cal.title)
                                    .font(SunwakeTypography.callout)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !excludedIDs.contains(cal.calendarIdentifier) },
                                    set: { include in
                                        if include {
                                            excludedIDs.remove(cal.calendarIdentifier)
                                        } else {
                                            excludedIDs.insert(cal.calendarIdentifier)
                                        }
                                        BriefingExclusionStore.excludedIDs = excludedIDs
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    } header: {
                        Label(provider.displayName(language: appState.selectedLanguage), systemImage: provider.systemImage)
                    } footer: {
                        Text(loc("Deaktivierte Kalender erscheinen nicht im Briefing.", "Disabled calendars won't appear in the briefing."))
                            .font(SunwakeTypography.caption)
                    }
                }
            }
        }
        .navigationTitle(loc("Kalender", "Calendar"))
        .listStyle(.insetGrouped)
        .onAppear {
            excludedIDs = BriefingExclusionStore.excludedIDs
        }
        .task {
            let store = EKEventStore()
            if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                availableCalendars = store.calendars(for: .event)
            }
        }
    }
}

// MARK: — About & Privacy

struct AboutView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "sun.horizon.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Sunwake")
                            .font(SunwakeTypography.title3.weight(.bold))
                        Text(loc("Dein Morgen-Briefing", "Your morning briefing"))
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section(loc("Technologie", "Technology")) {
                Label(loc("Gebaut mit SwiftUI & SwiftData", "Built with SwiftUI & SwiftData"), systemImage: "swift")
                Label(loc("KI auf dem Gerät mit Apple Foundation Models", "On-device AI via Apple Foundation Models"), systemImage: "brain")
                Label(loc("PDFs werden komplett auf dem Gerät verarbeitet", "PDFs processed entirely on-device"), systemImage: "lock.shield")
            }
        }
        .navigationTitle(loc("Über", "About"))
        .listStyle(.insetGrouped)
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section(loc("Deine Privatsphäre", "Your privacy")) {
                Label(loc("Kein Konto, kein Tracking", "No account, no tracking"), systemImage: "person.slash")
                Label(loc("KI läuft komplett auf dem Gerät", "AI runs entirely on-device"), systemImage: "iphone")
                Label(loc("PDFs bleiben auf deinem Gerät", "PDFs never leave your device"), systemImage: "doc.fill")
                Label(loc("Kalenderdaten bleiben lokal", "Calendar data stays local"), systemImage: "calendar")
            }
        }
        .navigationTitle(loc("Datenschutz", "Privacy"))
        .listStyle(.insetGrouped)
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}

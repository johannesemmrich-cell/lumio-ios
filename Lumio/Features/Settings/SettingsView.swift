import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var versionTapCount = 0
    @State private var showDeveloperUnlock = false
    @State private var showPaywall = false
    @State private var showResetOnboardingConfirm = false
    @State private var notificationHour: Int = UserDefaults.standard.integer(forKey: "notificationHour") == 0 ? 7 : UserDefaults.standard.integer(forKey: "notificationHour")
    @State private var notificationMinute: Int = UserDefaults.standard.integer(forKey: "notificationMinute")

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            List {
                // Calendar
                Section("Calendar") {
                    NavigationLink(destination: CalendarSettingsView()) {
                        Label("Connected Calendars", systemImage: "calendar")
                    }
                }

                // Notifications
                Section("Notifications") {
                    NotificationTimePicker(hour: $notificationHour, minute: $notificationMinute)
                }

                // Appearance
                Section("Appearance") {
                    ThemePickerRow(themeManager: themeManager)
                }

                // Subscription
                Section("Subscription") {
                    if subscriptionManager.effectivelyPremium {
                        Label("Premium Active", systemImage: "star.fill")
                            .foregroundStyle(Color.lumioAccent)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Premium", systemImage: "star")
                                Spacer()
                                Text("€2/mo")
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Restore Purchases") {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .foregroundStyle(.secondary)
                }

                // Premium design customization
                if subscriptionManager.effectivelyPremium {
                    Section("Premium") {
                        NavigationLink(destination: AppIconPickerView()) {
                            Label("App design anpassen", systemImage: "paintpalette.fill")
                        }
                    }
                }

                // About
                Section("About") {
                    NavigationLink(destination: AboutView()) {
                        Label("About Lumio", systemImage: "info.circle")
                    }
                    NavigationLink(destination: PrivacyView()) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                    Button {
                        showResetOnboardingConfirm = true
                    } label: {
                        Label("Onboarding wiederholen", systemImage: "arrow.counterclockwise")
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
                                    .font(LumioTypography.caption2.weight(.bold))
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
            .navigationTitle("Settings")
        }
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

    var body: some View {
        HStack {
            Label("Theme", systemImage: "paintbrush")
            Spacer()
            Picker("Theme", selection: $themeManager.currentTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
    }
}

// MARK: — Notification Time Picker

struct NotificationTimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    @State private var time: Date = {
        var comps = DateComponents()
        let h = UserDefaults.standard.integer(forKey: "notificationHour")
        let m = UserDefaults.standard.integer(forKey: "notificationMinute")
        comps.hour = h == 0 ? 7 : h
        comps.minute = m
        return Calendar.current.date(from: comps) ?? Date()
    }()

    var body: some View {
        DatePicker("Morning briefing", selection: $time, displayedComponents: .hourAndMinute)
            .onChange(of: time) { _, newTime in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                hour = comps.hour ?? 7
                minute = comps.minute ?? 30
                UserDefaults.standard.set(hour, forKey: "notificationHour")
                UserDefaults.standard.set(minute, forKey: "notificationMinute")
                Task {
                    await NotificationService.shared.scheduleDailyBriefing(
                        at: hour,
                        minute: minute,
                        previewText: String(localized: "Tap to see your morning briefing.")
                    )
                }
            }
    }
}

// MARK: — Calendar Settings

struct CalendarSettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        List {
            Section {
                CalendarProviderButton(name: "Apple Calendar", icon: "applelogo", color: .primary, isLoading: false) {}
                CalendarProviderButton(name: "Google Calendar", icon: "globe", color: .blue, isLoading: false, badge: "Coming soon") {}
                CalendarProviderButton(name: "Outlook", icon: "envelope.fill", color: .blue, isLoading: false, badge: "Coming soon") {}
            } footer: {
                if !subscriptionManager.effectivelyPremium {
                    Text("Free plan: 1 calendar. Upgrade to Premium to connect multiple calendars.")
                        .font(LumioTypography.caption)
                }
            }
        }
        .navigationTitle("Calendars")
        .listStyle(.insetGrouped)
    }
}

// MARK: — About & Privacy

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "sun.horizon.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Lumio")
                            .font(LumioTypography.title3.weight(.bold))
                        Text("Your morning briefing")
                            .font(LumioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Technology") {
                Label("Built with SwiftUI & SwiftData", systemImage: "swift")
                Label("On-device AI via Apple Foundation Models", systemImage: "brain")
                Label("PDFs processed entirely on-device", systemImage: "lock.shield")
            }
        }
        .navigationTitle("About")
        .listStyle(.insetGrouped)
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Your privacy") {
                Label("No account required", systemImage: "person.slash")
                Label("No data sent to servers", systemImage: "server.rack")
                Label("AI runs entirely on-device", systemImage: "iphone")
                Label("PDFs never leave your device", systemImage: "doc.fill")
                Label("Calendar data stays local", systemImage: "calendar")
            }
        }
        .navigationTitle("Privacy")
        .listStyle(.insetGrouped)
    }
}

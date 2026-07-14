import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStep
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer().frame(height: 20)
                stepContent
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStepView { viewModel.advance() }
        case .language:
            LanguageStepView(
                selected: $viewModel.selectedLanguage,
                onLanguageSelected: { code in viewModel.setLanguage(code, appState: appState) },
                onContinue: { viewModel.advance() }
            )
        case .calendar:
            CalendarStepView(viewModel: viewModel)
        case .notifications:
            NotificationsStepView(viewModel: viewModel)
        case .pdfUpload:
            PDFUploadStepView { viewModel.advance() }
        case .premium:
            PremiumIntroStepView { viewModel.completeOnboarding(appState: appState) }
        }
    }
}

// MARK: — Step: Welcome

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.breathe)

                Text("Sunwake")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Text("Your intelligent morning briefing")
                    .font(SunwakeTypography.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "calendar", color: .blue, title: "Your day at a glance", subtitle: "All your events, beautifully organized")
                FeatureRow(icon: "doc.text", color: .green, title: "Lecture highlights", subtitle: "Key points from your PDF slides")
                FeatureRow(icon: "waveform", color: .purple, title: "Spoken out loud", subtitle: "Listen while you get ready")
            }
            .padding(.horizontal, 4)

            SunwakeButton(title: "Get Started", style: .primary, action: onContinue)
        }
    }
}

// MARK: — Step: Language

struct LanguageStepView: View {
    @Binding var selected: String
    let onLanguageSelected: (String) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            // Header stays bilingual intentionally — user hasn't picked yet
            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
                Text("Sprache / Language")
                    .font(SunwakeTypography.title2)
                Text("Sunwake spricht Deutsch und English.")
                    .font(SunwakeTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                LanguageOption(code: "de", name: "Deutsch", flag: "🇩🇪", selected: $selected) {
                    onLanguageSelected("de")
                }
                LanguageOption(code: "en", name: "English", flag: "🇬🇧", selected: $selected) {
                    onLanguageSelected("en")
                }
            }

            SunwakeButton(title: "Weiter / Continue", style: .primary, action: onContinue)
        }
    }
}

struct LanguageOption: View {
    let code: String
    let name: String
    let flag: String
    @Binding var selected: String
    var onSelect: (() -> Void)? = nil

    var isSelected: Bool { selected == code }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { selected = code }
            onSelect?()
        } label: {
            HStack(spacing: 16) {
                Text(flag).font(.title2)
                Text(name).font(SunwakeTypography.body).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sunwakeAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.sunwakeAccent.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.sunwakeAccent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: — Step: Calendar

struct CalendarStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "calendar",
                iconColor: .blue,
                title: "Connect your calendar",
                subtitle: "Sunwake reads your calendar to prepare your morning briefing. It never uploads your data."
            )

            VStack(spacing: 12) {
                CalendarProviderButton(
                    name: "Apple Calendar",
                    icon: "applelogo",
                    color: .primary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.connectAppleCalendar() }
                }

                CalendarProviderButton(
                    name: "Google Calendar",
                    icon: "globe",
                    color: .blue,
                    isLoading: false,
                    badge: "Coming soon"
                ) {}

                CalendarProviderButton(
                    name: "Outlook",
                    icon: "envelope.fill",
                    color: .blue,
                    isLoading: false,
                    badge: "Coming soon"
                ) {}
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Skip for now") { viewModel.advance() }
                .font(SunwakeTypography.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct CalendarProviderButton: View {
    let name: String
    let icon: String
    let color: Color
    let isLoading: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(name)
                    .font(SunwakeTypography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(SunwakeTypography.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                } else if isLoading {
                    ProgressView().tint(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .disabled(badge != nil || isLoading)
    }
}

// MARK: — Step: Notifications

struct NotificationsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "bell.fill",
                iconColor: .orange,
                title: "Wake up to your day",
                subtitle: "Get a morning notification with a preview of your day. Default time: 7:30 AM."
            )

            NotificationPreviewCard()

            SunwakeButton(
                title: viewModel.isLoading ? "notification.requesting" : "notification.enable",
                style: .primary
            ) {
                Task { await viewModel.requestNotifications() }
            }
            .disabled(viewModel.isLoading)

            Button(LocalizedStringKey("notification.skip")) { viewModel.advance() }
                .font(SunwakeTypography.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct NotificationPreviewCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sunwake")
                        .font(SunwakeTypography.caption.weight(.semibold))
                    Spacer()
                    Text("7:30 AM")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Good morning ☀️")
                    .font(SunwakeTypography.callout.weight(.semibold))
                Text("09:00 Lecture · 11:30 Study Group · 14:00 Office Hours")
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

// MARK: — Step: PDF Upload

struct PDFUploadStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "doc.fill",
                iconColor: .green,
                title: "Upload your lecture slides",
                subtitle: "Add PDFs to get AI-powered summaries in your morning briefing. Everything stays on your device."
            )

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    FeatureRow(icon: "lock.fill", color: .green, title: "100% private", subtitle: "PDFs never leave your device")
                    Spacer()
                }
                HStack(spacing: 16) {
                    FeatureRow(icon: "icloud.fill", color: .blue, title: "iCloud sync", subtitle: "Available on all your devices")
                    Spacer()
                }
            }

            SunwakeButton(title: "Continue", style: .primary, action: onContinue)
            Text("You can upload PDFs anytime in the Library tab.")
                .font(SunwakeTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: — Step: Premium Intro

struct PremiumIntroStepView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                Text("premium.title", tableName: nil)
                    .font(SunwakeTypography.title2)
                Text("premium.subtitle", tableName: nil)
                    .font(SunwakeTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top, spacing: 12) {
                PremiumTierCard(
                    title: LocalizedStringKey("premium.free"),
                    color: .secondary,
                    features: ["premium.free.1", "premium.free.2", "premium.free.3", "premium.free.4"]
                )
                PremiumTierCard(
                    title: LocalizedStringKey("premium.paid"),
                    color: Color.sunwakeAccent,
                    features: ["premium.paid.1", "premium.paid.2", "premium.paid.3", "premium.paid.4", "premium.paid.5"],
                    highlighted: true
                )
            }

            VStack(spacing: 8) {
                SunwakeButton(title: "premium.cta", style: .primary, action: onComplete)
                Text("premium.price.hint", tableName: nil)
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct PremiumTierCard: View {
    let title: LocalizedStringKey
    let color: Color
    let features: [String]
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SunwakeTypography.callout.weight(.bold))
                .foregroundStyle(highlighted ? color : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                ForEach(features, id: \.self) { key in
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(color)
                        Text(LocalizedStringKey(key))
                            .font(SunwakeTypography.caption)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlighted ? color.opacity(0.07) : Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(highlighted ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

// MARK: — Shared sub-components

struct StepHeader: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(iconColor)
                .symbolEffect(.bounce, value: true)

            Text(title)
                .font(SunwakeTypography.title2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(SunwakeTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SunwakeTypography.callout.weight(.medium))
                Text(subtitle)
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SunwakeButton: View {
    let title: LocalizedStringKey
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle { case primary, secondary }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SunwakeTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    style == .primary
                        ? AnyShapeStyle(Color.sunwakeAccent)
                        : AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
                )
                .foregroundStyle(style == .primary ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

// MARK: — Briefing Detail Sheet

struct BriefingDetailView: View {
    let fullSummary: String
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let weather: WeatherData?
    let language: String
    let accentColor: Color
    let accentColorHex: String

    @ObservedObject var speechService: SpeechService
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState

    @State private var transformedText: String?
    @State private var isTransforming = false
    @State private var activeTransformation: BriefingTransformation?
    @State private var selectedEvent: CalendarEvent?
    @State private var selectedReminder: ReminderItem?

    @Environment(\.dismiss) private var dismiss

    private let ai = AIService()

    private var displayText: String { transformedText ?? fullSummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                briefingTextSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                shortcutBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    ttsButton
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Today", feature: "Briefing Detail", element: "Full Briefing")
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $selectedReminder) { reminder in
            ReminderDetailSheet(reminder: reminder, accentColor: accentColor)
        }
    }

    // MARK: — Briefing Text

    private var briefingTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !displayText.isEmpty {
                Text(buildAttributedBriefing())
                    .font(.system(.body))
                    .lineSpacing(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.3), value: displayText)
                    .environment(\.openURL, OpenURLAction { url in
                        handleLink(url)
                        return .handled
                    })
            } else {
                Text(language == "de" ? "Briefing wird geladen…" : "Loading briefing…")
                    .foregroundStyle(.secondary)
                    .font(.system(.body))
            }

            if transformedText != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { transformedText = nil }
                } label: {
                    Label(language == "de" ? "Original" : "Original", systemImage: "arrow.uturn.left")
                        .font(LumioTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    // MARK: — TTS Button (compact)

    private var ttsButton: some View {
        Button {
            HapticFeedback.impact(.light)
            if speechService.isPlaying {
                speechService.pause()
            } else if speechService.isPaused {
                speechService.resume()
            } else {
                startPlayback()
            }
        } label: {
            Image(systemName: speechService.isPlaying ? "pause.fill" : (speechService.isPaused ? "play.fill" : "speaker.wave.2"))
                .font(.callout.weight(.medium))
                .foregroundStyle(accentColor)
        }
    }

    // MARK: — Shortcut Bar

    private var shortcutBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                shortcutButton(
                    icon: "list.bullet",
                    label: language == "de" ? "Stichpunkte" : "Bullet Points",
                    transformation: .bulletPoints
                )
                shortcutButton(
                    icon: "text.badge.minus",
                    label: language == "de" ? "Kürzer" : "Shorter",
                    transformation: .condense
                )
                shortcutButton(
                    icon: "text.badge.plus",
                    label: language == "de" ? "Ausführlicher" : "More Detail",
                    transformation: .expand
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 2)

                Button {
                    sendToChat()
                } label: {
                    Label(
                        language == "de" ? "An Chat" : "To Chat",
                        systemImage: "bubble.left.fill"
                    )
                    .font(LumioTypography.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accentColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func shortcutButton(icon: String, label: String, transformation: BriefingTransformation) -> some View {
        let isActive = activeTransformation == transformation && isTransforming
        Button {
            guard !isTransforming else { return }
            Task { await applyTransformation(transformation) }
        } label: {
            HStack(spacing: 6) {
                if isActive {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(accentColor)
                } else {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(label)
                    .font(LumioTypography.caption.weight(.semibold))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(accentColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(isTransforming)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // MARK: — Attributed Text Builder

    private func buildAttributedBriefing() -> AttributedString {
        let text = displayText
        let mutable = NSMutableAttributedString(string: text)
        let nsStr = text as NSString

        for event in events {
            guard !event.title.isEmpty else { continue }
            var location = 0
            while location < nsStr.length {
                let range = nsStr.range(
                    of: event.title,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: location, length: nsStr.length - location)
                )
                guard range.location != NSNotFound else { break }
                mutable.addAttribute(.foregroundColor, value: UIColor(cgColor: event.calendarColor), range: range)
                if let url = briefingURL(scheme: "event", id: event.id) {
                    mutable.addAttribute(.link, value: url, range: range)
                }
                location = range.upperBound
            }
        }

        for reminder in reminders {
            guard !reminder.title.isEmpty else { continue }
            var location = 0
            while location < nsStr.length {
                let range = nsStr.range(
                    of: reminder.title,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: location, length: nsStr.length - location)
                )
                guard range.location != NSNotFound else { break }
                mutable.addAttribute(.foregroundColor, value: UIColor(accentColor), range: range)
                if let url = briefingURL(scheme: "reminder", id: reminder.id) {
                    mutable.addAttribute(.link, value: url, range: range)
                }
                location = range.upperBound
            }
        }

        return (try? AttributedString(mutable, including: \.uiKit)) ?? AttributedString(text)
    }

    // Use query parameters so EventKit IDs (which may contain '/') don't break path parsing.
    private func briefingURL(scheme: String, id: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "lumio"
        comps.host = scheme
        comps.queryItems = [URLQueryItem(name: "id", value: id)]
        return comps.url
    }

    private func handleLink(_ url: URL) {
        guard url.scheme == "lumio" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = comps?.queryItems?.first(where: { $0.name == "id" })?.value ?? ""
        guard !id.isEmpty else { return }
        HapticFeedback.selection()
        switch url.host {
        case "event":
            selectedEvent = events.first { $0.id == id }
        case "reminder":
            selectedReminder = reminders.first { $0.id == id }
        default: break
        }
    }

    // MARK: — Transformations

    private func applyTransformation(_ t: BriefingTransformation) async {
        guard !isTransforming else { return }
        isTransforming = true
        activeTransformation = t
        defer { isTransforming = false; activeTransformation = nil }
        let result = await ai.transformBriefing(displayText, into: t, language: language)
        withAnimation(.easeInOut(duration: 0.3)) { transformedText = result }
    }

    private func sendToChat() {
        appState.pendingBriefingForChat = displayText
        dismiss()
    }

    // MARK: — TTS

    /// The exact string that gets spoken.
    /// No weather prefix: `displayText` (AI summary and fallback alike) already
    /// leads with the weather, so a prefix would have it spoken twice.
    private var speechText: String { displayText }

    private func startPlayback() {
        speechService.speak(
            [SpeechItem(title: language == "de" ? "Briefing" : "Briefing",
                        text: speechText,
                        language: language == "de" ? "de-DE" : "en-US")],
            accentColorHex: accentColorHex
        )
    }

    private var dateTitle: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: — Reminder Detail Sheet

struct ReminderDetailSheet: View {
    let reminder: ReminderItem
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                            if !reminder.priorityLabel.isEmpty {
                                Text(reminder.priorityLabel)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(LumioTypography.body.weight(.semibold))
                            if !reminder.priorityLabel.isEmpty {
                                Text(reminder.priorityLabel + " Priorität")
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let due = reminder.dueDate {
                    Section("Fälligkeit") {
                        Label(due.formatted(.dateTime.day().month().hour().minute()),
                              systemImage: "clock")
                    }
                }

                if let notes = reminder.notes, !notes.isEmpty {
                    Section("Notizen") {
                        Text(notes)
                            .font(LumioTypography.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Erinnerung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

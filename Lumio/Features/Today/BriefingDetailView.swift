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

    @State private var condensedSummary: String?
    @State private var isCondensing = false
    @State private var selectedEvent: CalendarEvent?

    @Environment(\.dismiss) private var dismiss

    private let ai = AIService()

    private var displaySummary: String { condensedSummary ?? fullSummary }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                playCard
                summaryCard
                if !events.isEmpty { eventsSection }
                if !reminders.isEmpty { remindersSection }
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: — Play Card

    private var playCard: some View {
        VStack(spacing: 14) {
            // Controls
            HStack(spacing: 28) {
                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipBackward()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    HapticFeedback.impact(.medium)
                    if speechService.isPlaying {
                        speechService.pause()
                    } else if speechService.isPaused {
                        speechService.resume()
                    } else {
                        startPlayback()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 72, height: 72)
                            .shadow(color: accentColor.opacity(0.35), radius: 12, y: 4)
                        Image(systemName: speechService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: speechService.isPlaying ? 0 : 2)
                    }
                }

                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipForward()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.25), value: speechService.isPlaying || speechService.isPaused)
            .frame(maxWidth: .infinity)

            // Progress / label
            if speechService.isPlaying || speechService.isPaused {
                VStack(spacing: 6) {
                    ProgressView(value: max(0, min(1, speechService.progress)))
                        .tint(accentColor)
                    Text(speechService.currentItemTitle)
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .transition(.opacity)
            } else {
                Text("Briefing vorlesen")
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.2), value: speechService.isPlaying)
    }

    // MARK: — Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text("KI-Zusammenfassung")
                        .font(LumioTypography.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.5)
                }
                .foregroundStyle(accentColor)

                Spacer()

                if condensedSummary != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { condensedSummary = nil }
                    } label: {
                        Text("Vollständig")
                            .font(LumioTypography.caption.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                }
            }

            // Summary text
            Text(displaySummary)
                .font(.system(.callout))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.3), value: displaySummary)

            Divider()

            // Condense button
            HStack {
                Spacer()
                Button {
                    Task { await condense() }
                } label: {
                    HStack(spacing: 6) {
                        if isCondensing {
                            ProgressView().scaleEffect(0.7)
                                .tint(accentColor)
                        } else {
                            Image(systemName: "text.badge.minus")
                                .font(.caption.weight(.semibold))
                        }
                        Text(isCondensing ? "Wird kürzer gefasst…" : "Kürzer zusammenfassen")
                            .font(LumioTypography.caption.weight(.semibold))
                    }
                    .foregroundStyle(condensedSummary == nil ? accentColor : Color.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill((condensedSummary == nil ? accentColor : Color.secondary).opacity(0.1))
                    )
                }
                .disabled(isCondensing || condensedSummary != nil)
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: condensedSummary != nil)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: — Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Termine", icon: "calendar", count: events.count)

            VStack(spacing: 8) {
                ForEach(events) { event in
                    Button {
                        HapticFeedback.selection()
                        selectedEvent = event
                    } label: {
                        BriefingEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: — Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Erinnerungen", icon: "checklist", count: reminders.count)

            VStack(spacing: 0) {
                ForEach(Array(reminders.enumerated()), id: \.element.id) { i, reminder in
                    VStack(spacing: 0) {
                        BriefingReminderRow(reminder: reminder, accentColor: accentColor)
                        if i < reminders.count - 1 {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    // MARK: — Helpers

    @ViewBuilder
    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(LumioTypography.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
            Text("\(count)")
                .font(LumioTypography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(accentColor))
        }
        .foregroundStyle(.secondary)
    }

    private var dateTitle: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func startPlayback() {
        let isDE = language == "de"
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        var parts: [String] = []
        if let w = weather {
            let t = Int(w.temperatureCurrent.rounded())
            parts.append(isDE ? "Wetter: \(w.conditionLabel), \(t) Grad." : "Weather: \(w.conditionLabel), \(t) degrees.")
        }
        for event in events {
            let time = event.isAllDay
                ? (isDE ? "ganztägig" : "all day")
                : (isDE ? "um \(fmt.string(from: event.startDate)) Uhr" : "at \(fmt.string(from: event.startDate))")
            parts.append(isDE ? "\(event.title) \(time)." : "\(event.title) \(time).")
        }
        if !reminders.isEmpty {
            let titles = reminders.prefix(3).map(\.title).joined(separator: ", ")
            parts.append(isDE ? "Erinnerungen: \(titles)." : "Reminders: \(titles).")
        }
        parts.append(isDE ? "Das war dein Briefing!" : "That's your briefing!")
        let text = parts.joined(separator: " ")
        speechService.speak(
            [SpeechItem(title: "Briefing", text: text, language: language == "de" ? "de-DE" : "en-US")],
            accentColorHex: accentColorHex
        )
    }

    private func condense() async {
        guard !isCondensing, condensedSummary == nil else { return }
        isCondensing = true
        let short = await ai.summarizeBriefing(
            events: events, reminders: reminders, weather: weather,
            pdfTexts: [], language: language, length: .short, style: .friendly
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            condensedSummary = short
            isCondensing = false
        }
    }
}

// MARK: — Briefing Event Row

private struct BriefingEventRow: View {
    let event: CalendarEvent

    private var timeString: String {
        if event.isAllDay { return "Ganztägig" }
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var isNow: Bool {
        let now = Date()
        return !event.isAllDay && event.startDate <= now && event.endDate >= now
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 4, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(LumioTypography.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(timeString)
                        .font(LumioTypography.caption)

                    if let loc = event.location, !loc.isEmpty {
                        Text("·")
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(loc)
                            .lineLimit(1)
                            .font(LumioTypography.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isNow {
                Text("Jetzt")
                    .font(LumioTypography.caption2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.12)))
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: — Briefing Reminder Row

private struct BriefingReminderRow: View {
    let reminder: ReminderItem
    let accentColor: Color

    private var timeString: String? {
        guard let d = reminder.dueDate else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if !reminder.priorityLabel.isEmpty {
                    Text(reminder.priorityLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(LumioTypography.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let t = timeString {
                Text(t)
                    .font(LumioTypography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 14)
            }
        }
        .padding(.vertical, 12)
    }
}

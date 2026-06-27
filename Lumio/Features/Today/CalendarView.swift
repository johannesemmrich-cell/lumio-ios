import SwiftUI
import EventKit
import SwiftData

// MARK: — Main Calendar View

struct LumioCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekStripView(selectedDate: $viewModel.selectedDate)
                    .background(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)

                if !viewModel.availableCalendars.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            CalendarFilterPill(title: "Alle", color: .accentColor,
                                isSelected: viewModel.selectedCalendarIDs.isEmpty) {
                                withAnimation(.spring(duration: 0.2)) { viewModel.selectedCalendarIDs = [] }
                            }
                            ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { cal in
                                CalendarFilterPill(
                                    title: cal.title,
                                    color: Color(cgColor: cal.cgColor),
                                    isSelected: viewModel.selectedCalendarIDs.contains(cal.calendarIdentifier)
                                ) {
                                    withAnimation(.spring(duration: 0.2)) {
                                        viewModel.toggleCalendar(cal.calendarIdentifier)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(uiColor: .systemBackground))
                }

                Divider()

                Group {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.filteredEvents.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: viewModel.filteredEvents.map(\.id))
            }
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Heute") {
                        withAnimation(.spring(duration: 0.3)) { viewModel.selectedDate = Date() }
                    }
                    .disabled(viewModel.selectedDate.isToday)
                }
                if appState.isDeveloperModeActive {
                    ToolbarItem(placement: .topBarLeading) {
                        DeveloperFeedbackButton(screen: "Calendar", feature: "Calendar View", element: "Navigation")
                    }
                }
            }
            .task { await viewModel.setup() }
            .onChange(of: viewModel.selectedDate) { Task { await viewModel.fetchEvents() } }
            .onChange(of: viewModel.selectedCalendarIDs) { Task { await viewModel.fetchEvents() } }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
                    .environmentObject(subscriptionManager)
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Day header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(LumioTypography.headline)
                        Text("\(viewModel.filteredEvents.count) Termin\(viewModel.filteredEvents.count == 1 ? "" : "e")")
                            .font(LumioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                VStack(spacing: 6) {
                    ForEach(viewModel.filteredEvents) { event in
                        AgendaEventRow(event: event) {
                            selectedEvent = event
                        }
                        .padding(.horizontal, 16)
                        .developerFeedbackOverlay(
                            isActive: appState.isDeveloperModeActive,
                            screen: "Calendar",
                            feature: "Events",
                            element: "Event: \(event.title)"
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: viewModel.selectedDate.isToday ? "sun.max.fill" : "calendar.badge.clock")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.35))
            Text(viewModel.selectedDate.isToday ? "Freier Tag" : "Keine Termine")
                .font(LumioTypography.title3.weight(.semibold))
            Text(viewModel.selectedDate.isToday
                 ? "Heute sind keine Termine eingetragen."
                 : "An diesem Tag sind keine Termine.")
                .font(LumioTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: — Week Strip

struct WeekStripView: View {
    @Binding var selectedDate: Date
    @State private var weekOffset: Int = 0

    private var weekDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today)!
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var monthLabel: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let cal = Calendar.current
        let firstMonth = cal.component(.month, from: first)
        let lastMonth = cal.component(.month, from: last)
        if firstMonth == lastMonth {
            return first.formatted(.dateTime.month(.wide).year())
        }
        return "\(first.formatted(.dateTime.month(.abbreviated))) / \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button { withAnimation(.spring(duration: 0.25)) { weekOffset -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
                }

                Spacer()

                Text(monthLabel)
                    .font(LumioTypography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.2), value: monthLabel)

                Spacer()

                Button { withAnimation(.spring(duration: 0.25)) { weekOffset += 1 } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    DayButton(
                        date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    ) {
                        withAnimation(.spring(duration: 0.22)) { selectedDate = day }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 10)
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    private var isToday: Bool { date.isToday }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 36, height: 36)
                    } else if isToday {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            .frame(width: 36, height: 36)
                    }

                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: isSelected)
    }
}

// MARK: — Calendar Filter Pill

struct CalendarFilterPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
                    .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.35) : Color.clear, lineWidth: 1))
            )
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.18), value: isSelected)
    }
}

// MARK: — Agenda Event Row

struct AgendaEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private var timeString: String {
        if event.isAllDay { return "Ganztägig" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var duration: String {
        guard !event.isAllDay else { return "" }
        let mins = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        if mins < 60 { return "\(mins) Min." }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h) Std." : "\(h)h \(m)m"
    }

    private var isNow: Bool {
        guard !event.isAllDay else { return false }
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(cgColor: event.calendarColor))
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(LumioTypography.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 10) {
                                Label(timeString, systemImage: "clock")
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.secondary)

                                if !duration.isEmpty {
                                    Text(duration)
                                        .font(LumioTypography.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            if let loc = event.location, !loc.isEmpty {
                                Label(loc, systemImage: "mappin")
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 6) {
                            if isNow {
                                Text("Jetzt")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.green))
                            }

                            if event.notes != nil && !(event.notes?.isEmpty ?? true) {
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(cgColor: event.calendarColor))
                            .frame(width: 6, height: 6)
                        Text(event.calendarTitle)
                            .font(LumioTypography.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 12)
                .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Event Detail Sheet

struct EventDetailSheet: View {
    let event: CalendarEvent
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var matchingNotes: [CalendarEventNote]
    @State private var draftNotes: String = ""
    @State private var showAIChat = false

    init(event: CalendarEvent) {
        self.event = event
        let eid = event.id
        _matchingNotes = Query(filter: #Predicate<CalendarEventNote> { $0.eventIdentifier == eid })
    }

    private var existingNote: CalendarEventNote? { matchingNotes.first }
    private var hasChanges: Bool { draftNotes != (existingNote?.customNotes ?? "") }

    private var timeString: String {
        if event.isAllDay { return "Ganztägig" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(cgColor: event.calendarColor))
                                .frame(width: 6, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(LumioTypography.title3.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(cgColor: event.calendarColor))
                                        .frame(width: 7, height: 7)
                                    Text(event.calendarTitle)
                                        .font(LumioTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        // Meta rows
                        metaRow(icon: "clock", text: timeString)
                        if let loc = event.location, !loc.isEmpty {
                            metaRow(icon: "mappin", text: loc)
                        }
                        metaRow(icon: "calendar", text: event.selectedDate)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Apple Calendar notes
                    if let notes = event.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Aus der Kalender-App", systemImage: "calendar.badge.checkmark")
                                .font(LumioTypography.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(LumioTypography.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    // User notes
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meine Notizen", systemImage: "pencil.and.outline")
                            .font(LumioTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $draftNotes)
                            .font(LumioTypography.body)
                            .frame(minHeight: 100)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .tertiarySystemBackground))
                            )
                            .onChange(of: draftNotes) { _, _ in }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // AI Chat (Premium)
                    if subscriptionManager.effectivelyPremium {
                        Button {
                            showAIChat = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.lumioAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mit KI besprechen")
                                        .font(LumioTypography.callout.weight(.semibold))
                                    Text("Fragen stellen, Zusammenhänge entdecken")
                                        .font(LumioTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mit KI besprechen")
                                    .font(LumioTypography.callout)
                                    .foregroundStyle(.secondary)
                                Text("Nur mit Premium")
                                    .font(LumioTypography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    Spacer().frame(height: 32)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") { saveNotes() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
            .onAppear {
                draftNotes = existingNote?.customNotes ?? ""
            }
            .sheet(isPresented: $showAIChat) {
                EventAIChatSheet(event: event, userNotes: draftNotes)
            }
        }
    }

    @ViewBuilder
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(LumioTypography.callout)
                .foregroundStyle(.primary)
        }
    }

    private func saveNotes() {
        if let existing = existingNote {
            existing.customNotes = draftNotes
            existing.updatedAt = Date()
        } else {
            let note = CalendarEventNote(eventIdentifier: event.id, customNotes: draftNotes)
            modelContext.insert(note)
        }
        dismiss()
    }
}

private extension CalendarEvent {
    var selectedDate: String {
        startDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }
}

// MARK: — Event AI Chat Sheet

struct EventAIChatSheet: View {
    let event: CalendarEvent
    let userNotes: String
    @StateObject private var viewModel: EventChatViewModel
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(event: CalendarEvent, userNotes: String) {
        self.event = event
        self.userNotes = userNotes
        _viewModel = StateObject(wrappedValue: EventChatViewModel(event: event, userNotes: userNotes))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context chip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Label(event.title, systemImage: "calendar")
                            .font(LumioTypography.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(cgColor: event.calendarColor).opacity(0.12))
                                    .overlay(Capsule().strokeBorder(Color(cgColor: event.calendarColor).opacity(0.3), lineWidth: 1))
                            )
                            .foregroundStyle(Color(cgColor: event.calendarColor))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemBackground))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { msg in
                                ChatBubble(message: msg).id(msg.id)
                            }
                            if viewModel.isThinking {
                                ThinkingIndicator()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                ChatInputBar(
                    text: $viewModel.inputText,
                    isThinking: viewModel.isThinking,
                    focused: $inputFocused
                ) {
                    Task { await viewModel.sendMessage() }
                }
            }
            .navigationTitle("KI-Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { viewModel.setup() }
        }
    }
}

@MainActor
final class EventChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isThinking = false

    private let aiService = AIService()
    private let event: CalendarEvent
    private let userNotes: String

    init(event: CalendarEvent, userNotes: String) {
        self.event = event
        self.userNotes = userNotes
    }

    func setup() {
        guard messages.isEmpty else { return }
        var parts: [String] = []
        if let notes = event.notes, !notes.isEmpty { parts.append("Kalender-Notiz: \"\(notes)\"") }
        if !userNotes.isEmpty { parts.append("Meine Notiz: \"\(userNotes)\"") }
        let context = parts.isEmpty ? "" : " Kontext: \(parts.joined(separator: " | "))"

        let greeting = "Hallo! Ich kenne deinen Termin **\(event.title)**.\(context) Was möchtest du wissen oder besprechen?"
        messages = [ChatMessage(role: .assistant, text: greeting, timestamp: Date())]
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))
        isThinking = true
        defer { isThinking = false }

        var contextParts = ["Termin: \(event.title)"]
        if !event.isAllDay {
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
            contextParts.append("Zeit: \(fmt.string(from: event.startDate))–\(fmt.string(from: event.endDate))")
        }
        if let loc = event.location, !loc.isEmpty { contextParts.append("Ort: \(loc)") }
        if let notes = event.notes, !notes.isEmpty { contextParts.append("Kalender-Notiz: \(notes)") }
        if !userNotes.isEmpty { contextParts.append("Meine Notiz: \(userNotes)") }

        let fullQuestion = "[\(contextParts.joined(separator: " | "))] \(text)"
        let ctx = BriefingContext(todayEvents: [], pdfSummaries: [], date: Date())
        let reply = await aiService.answerQuestion(fullQuestion, context: ctx)
        messages.append(ChatMessage(role: .assistant, text: reply, timestamp: Date()))
    }
}

// MARK: — ViewModel

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var events: [CalendarEvent] = []
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var isLoading: Bool = false

    private let calendarService = CalendarService()

    var filteredEvents: [CalendarEvent] {
        guard !selectedCalendarIDs.isEmpty else { return events }
        return events.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
    }

    func setup() async {
        let _ = await calendarService.requestAccess()
        availableCalendars = calendarService.availableCalendars()
        await fetchEvents()
    }

    func fetchEvents() async {
        isLoading = true
        defer { isLoading = false }
        await calendarService.fetchEvents(for: selectedDate)
        events = calendarService.todayEvents
    }

    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }
    }
}

// MARK: — Date helpers

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}

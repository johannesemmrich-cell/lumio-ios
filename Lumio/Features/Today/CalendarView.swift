import SwiftUI
import EventKit

struct LumioCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week strip
                WeekStripView(selectedDate: $viewModel.selectedDate)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemBackground))

                Divider()

                // Calendar filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CalendarFilterPill(
                            title: LocalizedStringKey("calendar.allCalendars"),
                            color: .accentColor,
                            isSelected: viewModel.selectedCalendarIDs.isEmpty
                        ) {
                            viewModel.selectedCalendarIDs = []
                        }
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { cal in
                            CalendarFilterPill(
                                title: LocalizedStringKey(cal.title),
                                color: Color(cgColor: cal.cgColor),
                                isSelected: viewModel.selectedCalendarIDs.contains(cal.calendarIdentifier)
                            ) {
                                viewModel.toggleCalendar(cal.calendarIdentifier)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(uiColor: .systemBackground))

                Divider()

                // Events list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredEvents.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        LocalizedStringKey("calendar.noEvents"),
                        systemImage: "calendar.badge.clock",
                        description: Text(viewModel.selectedDate.isToday ? "Freier Tag 🎉" : "Keine Termine an diesem Tag.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(viewModel.filteredEvents) { event in
                                    AgendaEventRow(event: event)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                        .developerFeedbackOverlay(
                                            isActive: appState.isDeveloperModeActive,
                                            screen: "Calendar",
                                            feature: "Events",
                                            element: "Event: \(event.title)"
                                        )
                                }
                            } header: {
                                HStack {
                                    Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                                        .font(LumioTypography.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(viewModel.filteredEvents.count) Termin\(viewModel.filteredEvents.count == 1 ? "" : "e")")
                                        .font(LumioTypography.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemGroupedBackground))
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("calendar.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.selectedDate = Date()
                    } label: {
                        Text(LocalizedStringKey("calendar.today"))
                            .font(LumioTypography.caption.weight(.semibold))
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
        let startOfWeek = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today)!
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfWeek))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Week navigation
            HStack {
                Button { weekOffset -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(weekLabel)
                    .font(LumioTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { weekOffset += 1 } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Day buttons
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    DayButton(date: day, isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)) {
                        withAnimation(.spring(duration: 0.2)) { selectedDate = day }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var weekLabel: String {
        let cal = Calendar.current
        if weekOffset == 0 { return "Diese Woche" }
        if weekOffset == 1 { return "Nächste Woche" }
        if weekOffset == -1 { return "Letzte Woche" }
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(first.formatted(.dateTime.day().month())) – \(last.formatted(.dateTime.day().month(.wide)))"
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    private var dayLetter: String {
        date.formatted(.dateTime.weekday(.narrow))
    }
    private var dayNumber: String {
        date.formatted(.dateTime.day())
    }
    private var isToday: Bool { date.isToday }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayLetter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.15) : Color.clear))
                        .frame(width: 34, height: 34)
                    Text(dayNumber)
                        .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .primary))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: — Calendar Filter Pill

struct CalendarFilterPill: View {
    let title: LocalizedStringKey
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(LumioTypography.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color(uiColor: .secondarySystemBackground))
                    .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1))
            )
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: — Agenda Event Row

struct AgendaEventRow: View {
    let event: CalendarEvent

    private var timeRange: String {
        if event.isAllDay { return String(localized: "All day") }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var duration: String {
        guard !event.isAllDay else { return "" }
        let mins = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        if mins < 60 { return "\(mins) Min." }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h) Std." : "\(h) Std. \(m) Min."
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.isAllDay ? "–" : event.startDate.formatted(.dateTime.hour().minute()))
                    .font(LumioTypography.caption.weight(.semibold).monospacedDigit())
                if !event.isAllDay {
                    Text(duration)
                        .font(LumioTypography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 52, alignment: .trailing)

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(LumioTypography.callout.weight(.medium))
                    .lineLimit(2)

                if let loc = event.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin")
                        .font(LumioTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(event.calendarTitle)
                    .font(LumioTypography.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHappeningNow {
                Text("Jetzt")
                    .font(LumioTypography.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var isHappeningNow: Bool {
        let now = Date()
        return !event.isAllDay && event.startDate <= now && event.endDate >= now
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
        return events.filter { selectedCalendarIDs.contains($0.calendarTitle) }
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

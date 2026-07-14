import WidgetKit
import SwiftUI
import EventKit

// MARK: — Timeline Provider

struct SunwakeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunwakeWidgetEntry {
        SunwakeWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SunwakeWidgetEntry) -> Void) {
        completion(SunwakeWidgetEntry.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SunwakeWidgetEntry>) -> Void) {
        Task.detached {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> SunwakeWidgetEntry {
        let store = EKEventStore()
        guard case .fullAccess = EKEventStore.authorizationStatus(for: .event),
              (try? await store.requestFullAccessToEvents()) == true else {
            return SunwakeWidgetEntry.placeholder
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map { WidgetEvent(title: $0.title ?? "Event", startDate: $0.startDate, isAllDay: $0.isAllDay) }
        return SunwakeWidgetEntry(date: Date(), events: Array(events))
    }
}

struct WidgetEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let isAllDay: Bool

    var timeString: String {
        if isAllDay { return "All day" }
        return startDate.formatted(.dateTime.hour().minute())
    }
}

struct SunwakeWidgetEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]

    static let placeholder = SunwakeWidgetEntry(
        date: Date(),
        events: [
            WidgetEvent(title: "Lecture Economics", startDate: Date(), isAllDay: false),
            WidgetEvent(title: "Study Group", startDate: Date().addingTimeInterval(5400), isAllDay: false),
            WidgetEvent(title: "Office Hours", startDate: Date().addingTimeInterval(10800), isAllDay: false),
        ]
    )
}

// MARK: — Widget Views

struct SunwakeTodayWidget: Widget {
    let kind = "SunwakeTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunwakeWidgetProvider()) { entry in
            SunwakeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .systemBackground)
                }
        }
        .configurationDisplayName("Today's Briefing")
        .description("See your day at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SunwakeWidgetView: View {
    let entry: SunwakeWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: largeView
        }
    }

    // MARK: Small (2×2)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetHeader

            if entry.events.isEmpty {
                Text("Clear day ✨")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.events.prefix(2)) { event in
                    smallEventRow(event)
                }
                Spacer()
                if entry.events.count > 2 {
                    Text("+\(entry.events.count - 2) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
    }

    // MARK: Medium (4×2)

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                widgetHeader
                Spacer()
                Text("\(entry.events.count) event\(entry.events.count == 1 ? "" : "s")")
                    .font(.title2.weight(.bold))
                Text("today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 90)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if entry.events.isEmpty {
                    Text("No events today")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.events.prefix(3)) { event in
                        mediumEventRow(event)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
    }

    // MARK: Large (4×4)

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader
            Divider()
            if entry.events.isEmpty {
                Spacer()
                Label("Clear day ahead", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.events) { event in
                    largeEventRow(event)
                }
                Spacer()
            }
        }
        .padding(16)
    }

    // MARK: Header

    private var widgetHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.horizon.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text(Date(), format: .dateTime.weekday(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Event rows per size

    private func smallEventRow(_ event: WidgetEvent) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Text(event.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
    }

    private func mediumEventRow(_ event: WidgetEvent) -> some View {
        HStack(spacing: 8) {
            Text(event.timeString)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
            Text(event.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
    }

    private func largeEventRow(_ event: WidgetEvent) -> some View {
        HStack(spacing: 10) {
            Text(event.timeString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 2, height: 28)
            Text(event.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
    }
}

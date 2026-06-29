import SwiftUI
import Combine

// MARK: — Calendar Intent

enum CalendarIntent {
    case addEvent(title: String, date: Date?)
    case deleteEvent(title: String)
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isThinking: Bool = false

    var language: String = "en"

    private let aiService = AIService()
    private let calendarService = CalendarService()

    func setup(language: String = "en") async {
        self.language = language
        let _ = await calendarService.requestAccess()
        if messages.isEmpty {
            let greetingText = language == "de"
                ? "Hallo! Ich bin dein Lumio-Assistent. Ich kann dir bei deinem Tagesplan helfen, Fragen zu deinen Notizen beantworten oder Termine eintragen. Was kann ich für dich tun?"
                : String(localized: "Hi! I'm your Lumio assistant. I can help you with your schedule, answer questions about your lecture notes, or add events to your calendar. What can I help you with?")
            messages.append(ChatMessage(role: .assistant, text: greetingText, timestamp: Date()))
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))

        isThinking = true
        defer { isThinking = false }

        // Calendar intent detection
        if let intent = parseCalendarIntent(from: text) {
            await handleCalendarIntent(intent, originalText: text)
            return
        }

        await calendarService.fetchTodayEvents()
        let context = BriefingContext(
            todayEvents: calendarService.todayEvents,
            pdfSummaries: [],
            date: Date()
        )

        let response = await aiService.answerQuestion(text, context: context, language: language)
        messages.append(ChatMessage(role: .assistant, text: response, timestamp: Date()))
    }

    func clearHistory(language: String? = nil) {
        messages = []
        let lang = language ?? self.language
        Task { await setup(language: lang) }
    }

    func injectBriefingContext(_ text: String, language: String) {
        self.language = language
        let intro = language == "de"
            ? "Hier ist dein heutiges Briefing:\n\n\(text)\n\nStell mir Fragen dazu oder ich helfe dir beim Planen des Tages."
            : "Here's your today's briefing:\n\n\(text)\n\nAsk me questions or I can help you plan your day."
        messages.append(ChatMessage(role: .assistant, text: intro, timestamp: Date()))
    }

    // MARK: — Calendar Intent Parsing

    private func parseCalendarIntent(from text: String) -> CalendarIntent? {
        let lower = text.lowercased()

        let addKeywords = ["füge", "hinzufügen", "erstelle", "neuer termin", "add event", "create event", "schedule"]
        let deleteKeywords = ["lösche", "löschen", "entferne", "delete", "remove", "absagen", "cancel"]

        if addKeywords.contains(where: { lower.contains($0) }) {
            return .addEvent(title: extractEventTitle(from: text), date: extractDate(from: text))
        }
        if deleteKeywords.contains(where: { lower.contains($0) }) {
            return .deleteEvent(title: extractEventTitle(from: text))
        }
        return nil
    }

    private func extractEventTitle(from text: String) -> String {
        // Text in Anführungszeichen hat Priorität
        if let range = text.range(of: "\"([^\"]+)\"", options: .regularExpression) {
            return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        // Fallback: alles nach Schlüsselwort
        for keyword in ["mit ", "with ", "event ", "termin "] {
            if let range = text.lowercased().range(of: keyword) {
                let after = text[range.upperBound...]
                let trimmed = String(after).components(separatedBy: CharacterSet(charactersIn: ".,!?")).first ?? String(after)
                let cleaned = trimmed.trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return text
    }

    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches?.first?.date
    }

    private func handleCalendarIntent(_ intent: CalendarIntent, originalText: String) async {
        switch intent {
        case .addEvent(let title, let date):
            let targetDate = date ?? Date()
            let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
            let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
            do {
                try await calendarService.addEvent(title: title, startDate: start, endDate: end)
                let msg = language == "de"
                    ? "Termin '\(title)' wurde für \(start.formatted(.dateTime.day().month().hour().minute())) erstellt ✓"
                    : "Event '\(title)' created for \(start.formatted(.dateTime.day().month().hour().minute())) ✓"
                messages.append(ChatMessage(role: .assistant, text: msg, timestamp: Date()))
            } catch {
                messages.append(ChatMessage(role: .assistant, text: "Fehler beim Erstellen des Termins: \(error.localizedDescription)", timestamp: Date()))
            }
        case .deleteEvent:
            let msg = language == "de"
                ? "Um Termine zu löschen, öffne bitte den Kalender und tippe auf den Termin. Direkte Löschung per Chat wird aus Sicherheitsgründen nicht unterstützt."
                : "To delete events, please open the Calendar and tap the event. Direct deletion via chat is not supported for safety reasons."
            messages.append(ChatMessage(role: .assistant, text: msg, timestamp: Date()))
        }
    }
}

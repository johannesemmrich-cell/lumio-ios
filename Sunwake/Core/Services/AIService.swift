import Foundation
import FoundationModels
import SwiftUI

enum AICapabilityStatus: Equatable {
    case available
    case deviceNotSupported
    case modelNotReady
    case unknown

    var isAvailable: Bool { self == .available }

    var userMessage: LocalizedStringKey {
        switch self {
        case .available:
            return "AI features are ready on this device."
        case .deviceNotSupported:
            return "AI features require an iPhone 15 Pro or newer (iPhone 16 or 17). All other Sunwake features work perfectly without it."
        case .modelNotReady:
            return "The on-device AI model isn't ready yet. Make sure Apple Intelligence is enabled in Settings, then check back in a few minutes."
        case .unknown:
            return "Checking AI availability…"
        }
    }

    var icon: String {
        switch self {
        case .available: return "brain.fill"
        case .deviceNotSupported: return "iphone.slash"
        case .modelNotReady: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }
}

@MainActor
final class AIService: ObservableObject {
    @Published private(set) var capabilityStatus: AICapabilityStatus = .unknown
    @Published private(set) var isGenerating: Bool = false

    init() {
        Task { await checkCapability() }
    }

    // MARK: — Capability check

    func checkCapability() async {
        if #available(iOS 26.0, *) {
            capabilityStatus = Self.detectFoundationModels()
        } else {
            capabilityStatus = .deviceNotSupported
        }
    }

    /// The on-device model configured for transforming user-provided content
    /// (calendar, reminders, weather) — Apple's intended guardrail mode for
    /// summarization apps. The default guardrails run an extra safety model
    /// over the input that can misfire on benign personal data.
    nonisolated private static let generationModel = SystemLanguageModel(
        useCase: .general,
        guardrails: .permissiveContentTransformations
    )

    /// Maps the live FoundationModels availability onto our capability status.
    /// Availability can change at runtime (model download finishes, Apple
    /// Intelligence gets toggled), so callers re-check before every generation.
    @available(iOS 26.0, *)
    private static func detectFoundationModels() -> AICapabilityStatus {
        switch generationModel.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotSupported
        case .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady):
            return .modelNotReady
        default:
            return .unknown
        }
    }

    // MARK: — Briefing summary

    func summarizeBriefing(events: [CalendarEvent], reminders: [ReminderItem] = [], weather: WeatherData? = nil, pdfTexts: [String], language: String = "en", length: BriefingLength = .medium, style: BriefingStyle = .friendly) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        await checkCapability() // availability can change at runtime
        if capabilityStatus == .available, #available(iOS 26.0, *) {
            return await generateWithFoundationModels(events: events, reminders: reminders, weather: weather, pdfTexts: pdfTexts, language: language, length: length, style: style)
        }
        return buildFallbackSummary(events: events, reminders: reminders, weather: weather, language: language)
    }

    // MARK: — Tomorrow briefing (Premium preview)

    func summarizeTomorrowBriefing(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, language: String = "en", length: BriefingLength = .medium, style: BriefingStyle = .friendly) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        await checkCapability() // availability can change at runtime
        if capabilityStatus == .available, #available(iOS 26.0, *) {
            let prompt = buildTomorrowPrompt(events: events, reminders: reminders, weather: weather, language: language, length: length, style: style)
            if let result = await runFoundationModelsPrompt(prompt) { return result }
        }
        return buildTomorrowFallback(events: events, reminders: reminders, weather: weather, language: language)
    }

    private func buildTomorrowPrompt(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, language: String, length: BriefingLength, style: BriefingStyle) -> String {
        let isDE = language == "de"
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = events.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        let reminderLines = reminders.map { "- \($0.title)" }.joined(separator: "\n")

        let weekday = Self.tomorrowWeekdayName(language: language)
        let noEventsText = isDE ? "(keine Termine)" : "(no events)"
        let noRemindersText = isDE ? "(keine Erinnerungen)" : "(no reminders)"
        let langInstruction = isDE
            ? "Antworte auf Deutsch. \(style == .formal ? "Sei sachlich und präzise." : style == .concise ? "Sei sehr knapp." : "Sei warm und motivierend.")"
            : "Respond in English. \(style == .formal ? "Be professional and precise." : style == .concise ? "Be very brief." : "Be warm and encouraging.")"
        // Pinned opener, same trick as the daily briefing — the small
        // on-device model ignores softer greeting instructions.
        let opener = isDE ? "Dein Ausblick auf morgen, \(weekday):" : "Your look ahead to tomorrow, \(weekday):"
        let openerRule = isDE
            ? "Beginne exakt mit \"\(opener)\" und verwende keine andere Einleitung. Sprich über MORGEN, nicht über heute."
            : "Start exactly with \"\(opener)\" and use no other opener. Talk about TOMORROW, not today."
        let plainTextRule = isDE
            ? "Antworte ausschließlich als natürlicher Fließtext ohne Markdown, ohne Sternchen, ohne Überschriften."
            : "Respond only as natural flowing text — no markdown, no asterisks, no headings."
        let weatherSection = weather?.tomorrowSnippet(language: language).map { "\n\nTomorrow's weather forecast: \($0)" } ?? ""

        return """
        You are Sunwake, a calm and intelligent daily briefing assistant. Preview the user's day TOMORROW (\(weekday)).
        \(openerRule)\(weatherSection)

        Tomorrow's events (\(events.count) total):
        \(eventLines.isEmpty ? noEventsText : eventLines)

        Tomorrow's reminders (\(reminders.count) total):
        \(reminderLines.isEmpty ? noRemindersText : reminderLines)

        IMPORTANT: Mention EVERY event and EVERY reminder listed above — do not skip any. Do not invent items not listed.
        \(langInstruction) Write \(length.maxSentences) sentence(s), but always include all events and reminders even if that requires more sentences.
        \(plainTextRule)
        """
    }

    func buildTomorrowFallback(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, language: String) -> String {
        let isDE = language == "de"
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let weekday = Self.tomorrowWeekdayName(language: language)

        var parts: [String] = [isDE ? "Dein Ausblick auf morgen, \(weekday):" : "Your look ahead to tomorrow, \(weekday):"]

        if let forecast = weather?.tomorrowSnippet(language: language) {
            parts.append(isDE ? "Wetter: \(forecast)." : "Weather: \(forecast).")
        }

        if events.isEmpty && reminders.isEmpty {
            parts.append(isDE
                ? "Keine Termine oder Erinnerungen — ein freier Tag liegt vor dir."
                : "No events or reminders — a clear day is ahead of you.")
        } else {
            if !events.isEmpty {
                let eventList = events.map { "\($0.title) \(isDE ? "um" : "at") \(fmt.string(from: $0.startDate))" }.joined(separator: ", ")
                parts.append(isDE
                    ? (events.count == 1 ? "Ein Termin: \(eventList)." : "\(events.count) Termine: \(eventList).")
                    : (events.count == 1 ? "One event: \(eventList)." : "\(events.count) events: \(eventList)."))
            }
            if !reminders.isEmpty {
                let reminderList = reminders.map(\.title).joined(separator: ", ")
                parts.append(isDE
                    ? (reminders.count == 1 ? "Erinnerung: \(reminderList)." : "\(reminders.count) Erinnerungen: \(reminderList).")
                    : (reminders.count == 1 ? "Reminder: \(reminderList)." : "\(reminders.count) reminders: \(reminderList)."))
            }
        }

        return parts.joined(separator: " ")
    }

    private static func tomorrowWeekdayName(language: String) -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: language == "de" ? "de_DE" : "en_US")
        fmt.dateFormat = "EEEE"
        return fmt.string(from: tomorrow)
    }

    // MARK: — Chat answer

    func answerQuestion(_ question: String, context: BriefingContext, language: String = "en") async -> String {
        isGenerating = true
        defer { isGenerating = false }

        await checkCapability() // availability can change at runtime
        guard capabilityStatus == .available else {
            if language == "de" {
                return capabilityStatus == .deviceNotSupported
                    ? "KI-Chat benötigt ein iPhone 15 Pro oder neuer. Kalender und PDFs funktionieren weiterhin."
                    : "Das KI-Modell wird noch vorbereitet. Bitte versuche es gleich erneut."
            }
            return capabilityStatus == .deviceNotSupported
                ? "AI chat requires an iPhone 15 Pro or newer. Your calendar and PDF features still work perfectly."
                : "The AI model is getting ready. Try again in a moment."
        }

        if #available(iOS 26.0, *) {
            return await generateAnswerWithFoundationModels(question: question, context: context, language: language)
        }
        return buildRuleBasedAnswer(question: question, context: context, language: language)
    }

    // MARK: — Foundation Models integration (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithFoundationModels(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, pdfTexts: [String], language: String, length: BriefingLength, style: BriefingStyle) async -> String {
        let prompt = buildBriefingPrompt(events: events, reminders: reminders, weather: weather, pdfTexts: pdfTexts, language: language, length: length, style: style)
        return await runFoundationModelsPrompt(prompt) ?? buildFallbackSummary(events: events, reminders: reminders, weather: weather, language: language)
    }

    @available(iOS 26.0, *)
    private func generateAnswerWithFoundationModels(question: String, context: BriefingContext, language: String) async -> String {
        let prompt = buildChatPrompt(question: question, context: context, language: language)
        return await runFoundationModelsPrompt(prompt) ?? buildRuleBasedAnswer(question: question, context: context, language: language)
    }

    /// Single choke point for on-device generation: summaries, chat answers and
    /// transformations all go through here. Returns nil on any failure so the
    /// rule-based fallbacks kick in.
    @available(iOS 26.0, *)
    private func runFoundationModelsPrompt(_ prompt: String) async -> String? {
        // Re-check availability right before generating — it can change at
        // runtime (e.g. the model just finished downloading).
        let status = Self.detectFoundationModels()
        capabilityStatus = status
        guard status == .available else { return nil }

        // Run the session off the main actor so generation never blocks the UI.
        return await Task.detached(priority: .userInitiated) { () async -> String? in
            do {
                let session = LanguageModelSession(model: Self.generationModel)
                let response = try await session.respond(to: prompt)
                let cleaned = Self.sanitizeModelOutput(response.content)
                return cleaned.isEmpty ? nil : cleaned
            } catch {
                return nil
            }
        }.value
    }

    /// Strips markdown artifacts the model sometimes emits despite the prompt
    /// rules, so the text is safe to display verbatim AND to speak aloud.
    nonisolated static func sanitizeModelOutput(_ text: String) -> String {
        let withoutEmphasis = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")

        let lines = withoutEmphasis.components(separatedBy: "\n").map { line -> String in
            var cleaned = line
            // Markdown bullets ("* " / "- ") → the app's "• " style
            if let marker = cleaned.range(of: #"^\s*[*-]\s+"#, options: .regularExpression) {
                cleaned.replaceSubrange(marker, with: "• ")
            }
            // Markdown headers ("# ", "## ", …) → plain text
            if let header = cleaned.range(of: #"^\s*#+\s*"#, options: .regularExpression) {
                cleaned.removeSubrange(header)
            }
            return cleaned
        }

        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: — Briefing transformations

    func transformBriefing(_ text: String, into transformation: BriefingTransformation, language: String) async -> String {
        await checkCapability() // availability can change at runtime
        if capabilityStatus == .available, #available(iOS 26.0, *) {
            let prompt = buildTransformPrompt(text: text, transformation: transformation, language: language)
            if let result = await runFoundationModelsPrompt(prompt) { return result }
        }
        return fallbackTransform(text, transformation: transformation)
    }

    private func buildTransformPrompt(text: String, transformation: BriefingTransformation, language: String) -> String {
        let isDE = language == "de"
        let instruction: String
        switch transformation {
        case .condense:
            instruction = isDE
                ? "Fasse den folgenden Text auf maximal 2 Sätze zusammen. Nur das Wesentliche."
                : "Condense the following text to at most 2 sentences. Keep only what's essential."
        case .expand:
            instruction = isDE
                ? "Mache den folgenden Text deutlich länger und ausführlicher. Erwähne jeden Termin und jede Erinnerung einzeln mit Uhrzeit und Kontext. Füge motivierende Details hinzu. Kürze NICHTS weg – das Ergebnis muss länger als der Original-Text sein."
                : "Expand the following text significantly. Mention every event and reminder individually with time and context. Add motivating details. Do NOT shorten anything — the result must be longer than the input."
        case .bulletPoints:
            instruction = isDE
                ? "Wandle den folgenden Text in eine Stichpunktliste um. Jeden Punkt mit '• ' beginnen."
                : "Convert the following text into a bullet list. Start each point with '• '."
        }
        let noMarkdownRule = isDE
            ? "Kein Markdown: keine Sternchen (**), keine Rauten (#), keine Bindestrich-Listen (-)."
            : "No markdown: no asterisks (**), no hash headings (#), no dash lists (-)."
        return "\(instruction) \(noMarkdownRule)\n\nText:\n\(text)"
    }

    private func fallbackTransform(_ text: String, transformation: BriefingTransformation) -> String {
        switch transformation {
        case .condense:
            let sentences = text.components(separatedBy: ". ")
            let short = sentences.prefix(2).joined(separator: ". ")
            return sentences.count > 2 ? short + "." : short
        case .expand:
            return text
        case .bulletPoints:
            return text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "• \($0)" }
                .joined(separator: "\n")
        }
    }

    // MARK: — Prompt builders

    private func buildBriefingPrompt(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, pdfTexts: [String], language: String, length: BriefingLength, style: BriefingStyle) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = events.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        let dueTomorrowSuffix = language == "de" ? " (bis morgen)" : " (due tomorrow)"
        let reminderLines = reminders.map {
            "- \($0.title)\($0.isDueTomorrow ? dueTomorrowSuffix : "")"
        }.joined(separator: "\n")
        let pdfSection = pdfTexts.isEmpty ? "" : "\n\nLecture content available:\n" + pdfTexts.prefix(3).joined(separator: "\n---\n")

        let isDE = language == "de"
        let langInstruction: String
        let noEventsText: String
        let noRemindersText: String
        if isDE {
            langInstruction = "Antworte auf Deutsch. \(style == .formal ? "Sei sachlich und präzise." : style == .concise ? "Sei sehr knapp." : "Sei warm und motivierend.")"
            noEventsText = "(keine Termine)"
            noRemindersText = "(keine Erinnerungen)"
        } else {
            langInstruction = "Respond in English. \(style == .formal ? "Be professional and precise." : style == .concise ? "Be very brief." : "Be warm and encouraging.")"
            noEventsText = "(no events)"
            noRemindersText = "(no reminders)"
        }

        // Current time + daypart so the greeting matches (no "Guten Morgen" at
        // 4 pm). The greeting is pinned verbatim — the small on-device model
        // ignores softer "pick a fitting greeting" instructions.
        let (greeting, daypart) = BriefingNarrator.timeOfDay(language: language)
        let timeContext = isDE
            ? "Aktuelle Uhrzeit: \(fmt.string(from: Date())) (\(daypart)). Beginne exakt mit der Begrüßung \"\(greeting)!\" und verwende keine andere Begrüßung."
            : "Current time: \(fmt.string(from: Date())) (\(daypart)). Start exactly with the greeting \"\(greeting)!\" and use no other greeting."

        let plainTextRule = isDE
            ? "Antworte ausschließlich als natürlicher Fließtext ohne Markdown, ohne Sternchen, ohne Überschriften."
            : "Respond only as natural flowing text — no markdown, no asterisks, no headings."

        let weatherSection = weather.map { "\n\nWeather: \($0.briefingSnippet(language: language))" } ?? ""

        let eventCount = events.count
        let reminderCount = reminders.count

        return """
        You are Sunwake, a calm and intelligent daily briefing assistant.
        \(timeContext)\(weatherSection)

        Today's events (\(eventCount) total):
        \(eventLines.isEmpty ? noEventsText : eventLines)

        Today's reminders (\(reminderCount) total):
        \(reminderLines.isEmpty ? noRemindersText : reminderLines)\(pdfSection)

        IMPORTANT: Mention EVERY event and EVERY reminder listed above — do not skip any. Do not invent items not listed.
        \(langInstruction) Write \(length.maxSentences) sentence(s), but always include all events and reminders even if that requires more sentences.
        \(plainTextRule)
        """
    }

    private func buildChatPrompt(question: String, context: BriefingContext, language: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = context.todayEvents.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        let noEventsText = language == "de" ? "(keine Termine)" : "(no events)"
        let langInstruction = language == "de"
            ? "Antworte auf Deutsch. Sei kurz und direkt."
            : "Answer concisely in English."
        let plainTextRule = language == "de"
            ? "Antworte ausschließlich als natürlicher Fließtext ohne Markdown, ohne Sternchen, ohne Überschriften."
            : "Respond only as natural flowing text — no markdown, no asterisks, no headings."

        return """
        You are Sunwake, a helpful and concise AI assistant for a morning briefing app. Answer the user's question based on their calendar and lecture notes. Be brief and direct.

        Today's calendar:
        \(eventLines.isEmpty ? noEventsText : eventLines)

        User question: \(question)

        \(langInstruction) \(plainTextRule)
        """
    }

    // MARK: — Fallbacks (always work, no AI needed)

    func buildFallbackSummary(events: [CalendarEvent], reminders: [ReminderItem] = [], weather: WeatherData? = nil, language: String = "en") -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        var parts: [String] = []

        if let w = weather {
            parts.append("\(w.conditionLabel(language: language)), \(Int(w.temperatureCurrent.rounded()))°C.")
        }

        if language == "de" {
            if events.isEmpty && reminders.isEmpty {
                parts.append("Heute keine Termine oder Erinnerungen – genieß die freie Zeit.")
            } else {
                if !events.isEmpty {
                    let eventList = events.map { "\($0.title) um \(fmt.string(from: $0.startDate))" }.joined(separator: ", ")
                    parts.append(events.count == 1
                        ? "\(events[0].title) um \(fmt.string(from: events[0].startDate)) – dein einziger Termin."
                        : "\(events.count) Termine heute: \(eventList).")
                }
                if !reminders.isEmpty {
                    let reminderList = reminders.map { $0.title }.joined(separator: ", ")
                    parts.append(reminders.count == 1
                        ? "Erinnerung: \(reminders[0].title)."
                        : "\(reminders.count) Erinnerungen: \(reminderList).")
                }
            }
        } else {
            if events.isEmpty && reminders.isEmpty {
                parts.append("You have a clear day today. Enjoy the focus time.")
            } else {
                if !events.isEmpty {
                    let eventList = events.map { "\($0.title) at \(fmt.string(from: $0.startDate))" }.joined(separator: ", ")
                    parts.append(events.count == 1
                        ? "\(events[0].title) at \(fmt.string(from: events[0].startDate)) — that's your only event today."
                        : "\(events.count) events today: \(eventList).")
                }
                if !reminders.isEmpty {
                    let reminderList = reminders.map { $0.title }.joined(separator: ", ")
                    parts.append(reminders.count == 1
                        ? "Reminder: \(reminders[0].title)."
                        : "\(reminders.count) reminders: \(reminderList).")
                }
            }
        }

        return parts.joined(separator: " ")
    }

    func buildRuleBasedAnswer(question: String, context: BriefingContext, language: String = "en") -> String {
        let q = question.lowercased()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        if q.contains("today") || q.contains("heute") || q.contains("termin") || q.contains("event") {
            return buildFallbackSummary(events: context.todayEvents, language: language)
        }
        if q.contains("free") || q.contains("frei") || q.contains("available") || q.contains("verfügbar") {
            let busy = context.todayEvents.map { "\(fmt.string(from: $0.startDate))–\(fmt.string(from: $0.endDate))" }.joined(separator: ", ")
            if language == "de" {
                return busy.isEmpty ? "Du hast heute den ganzen Tag frei." : "Du bist beschäftigt um: \(busy)"
            }
            return busy.isEmpty
                ? "You're free all day today."
                : "You're busy at: \(busy)"
        }
        if language == "de" {
            return "Ich kann dir bei Fragen zu deinem Kalender und deinen Notizen helfen. Zum Beispiel: \"Was habe ich heute?\" oder \"Bin ich um 15 Uhr frei?\""
        }
        return "I can help you with questions about your calendar and lecture notes. For example: \"What do I have today?\" or \"Am I free at 3pm?\""
    }
}

// MARK: — Briefing Transformation

enum BriefingTransformation: Equatable {
    case condense, expand, bulletPoints
}

struct BriefingContext {
    let todayEvents: [CalendarEvent]
    let todayReminders: [ReminderItem]
    let weather: WeatherData?
    let pdfSummaries: [String]
    let date: Date

    init(todayEvents: [CalendarEvent], todayReminders: [ReminderItem] = [], weather: WeatherData? = nil, pdfSummaries: [String] = [], date: Date = Date()) {
        self.todayEvents = todayEvents
        self.todayReminders = todayReminders
        self.weather = weather
        self.pdfSummaries = pdfSummaries
        self.date = date
    }
}

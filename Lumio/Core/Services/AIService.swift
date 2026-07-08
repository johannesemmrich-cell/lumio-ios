import Foundation
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
            return "AI features require an iPhone 15 Pro or newer (iPhone 16 or 17). All other Lumio features work perfectly without it."
        case .modelNotReady:
            return "The on-device AI model is still preparing. Check back in a few minutes."
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
            capabilityStatus = await detectFoundationModels()
        } else {
            capabilityStatus = .deviceNotSupported
        }
    }

    @available(iOS 26.0, *)
    private func detectFoundationModels() async -> AICapabilityStatus {
        // FoundationModels.framework — iOS 26+, available on A17 Pro / M-chip devices
        // NSClassFromString fails for Swift types due to name mangling; we try multiple paths.

        // Try bridged ObjC name first, then Swift mangled name patterns
        let classNames = [
            "FoundationModels.SystemLanguageModel",
            "_TtC15FoundationModels18SystemLanguageModel",
        ]
        let found = classNames.contains { NSClassFromString($0) != nil }
        guard found else {
            // On iOS 26+ the framework exists but NSClassFromString is unreliable for Swift types.
            // Treat as modelNotReady so the user sees a friendlier message than "device not supported".
            return .modelNotReady
        }

        // Framework present — assume available; full capability check deferred until actual generation
        return .available
    }

    // MARK: — Briefing summary

    func summarizeBriefing(events: [CalendarEvent], reminders: [ReminderItem] = [], weather: WeatherData? = nil, pdfTexts: [String], language: String = "en", length: BriefingLength = .medium, style: BriefingStyle = .friendly) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        if capabilityStatus == .available, #available(iOS 26.0, *) {
            return await generateWithFoundationModels(events: events, reminders: reminders, weather: weather, pdfTexts: pdfTexts, language: language, length: length, style: style)
        }
        return buildFallbackSummary(events: events, reminders: reminders, weather: weather, language: language)
    }

    // MARK: — Chat answer

    func answerQuestion(_ question: String, context: BriefingContext, language: String = "en") async -> String {
        isGenerating = true
        defer { isGenerating = false }

        guard capabilityStatus == .available else {
            if language == "de" {
                return capabilityStatus == .deviceNotSupported
                    ? "KI-Chat benötigt ein iPhone 15 Pro oder neuer. Kalender und PDFs funktionieren weiterhin."
                    : "Das KI-Modell wird noch vorbereitet. Bitte versuche es gleich erneut."
            }
            return capabilityStatus == .deviceNotSupported
                ? String(localized: "AI chat requires an iPhone 15 Pro or newer. Your calendar and PDF features still work perfectly.")
                : String(localized: "The AI model is getting ready. Try again in a moment.")
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

    @available(iOS 26.0, *)
    private func runFoundationModelsPrompt(_ prompt: String) async -> String? {
        // Run ObjC runtime dispatch off the main thread to avoid blocking the UI.
        // Replace with direct FoundationModels import once the framework API is stable.
        let promptCopy = prompt
        return await Task.detached(priority: .userInitiated) {
            guard
                let modelClass = NSClassFromString("FoundationModels.SystemLanguageModel") as? NSObject.Type,
                let sessionClass = NSClassFromString("FoundationModels.LanguageModelSession") as? NSObject.Type
            else { return nil }

            let defaultSel = NSSelectorFromString("default")
            guard modelClass.responds(to: defaultSel) else { return nil }
            let model = modelClass.perform(defaultSel)?.takeUnretainedValue()

            let initSel = NSSelectorFromString("initWithModel:")
            guard let session = sessionClass.perform(initSel, with: model)?.takeRetainedValue() as? NSObject else { return nil }

            let respondSel = NSSelectorFromString("respondTo:")
            guard session.responds(to: respondSel) else { return nil }
            return session.perform(respondSel, with: promptCopy)?.takeUnretainedValue() as? String
        }.value
    }

    // MARK: — Briefing transformations

    func transformBriefing(_ text: String, into transformation: BriefingTransformation, language: String) async -> String {
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
        return "\(instruction)\n\nText:\n\(text)"
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

        let langInstruction: String
        let noEventsText: String
        let noRemindersText: String
        if language == "de" {
            langInstruction = "Antworte auf Deutsch. \(style == .formal ? "Sei sachlich und präzise." : style == .concise ? "Sei sehr knapp." : "Sei warm und motivierend.")"
            noEventsText = "(keine Termine)"
            noRemindersText = "(keine Erinnerungen)"
        } else {
            langInstruction = "Respond in English. \(style == .formal ? "Be professional and precise." : style == .concise ? "Be very brief." : "Be warm and encouraging.")"
            noEventsText = "(no events)"
            noRemindersText = "(no reminders)"
        }

        let weatherSection = weather.map { "\n\nWeather: \($0.briefingSnippet)" } ?? ""

        let eventCount = events.count
        let reminderCount = reminders.count

        return """
        You are Lumio, a calm and intelligent morning briefing assistant.\(weatherSection)

        Today's events (\(eventCount) total):
        \(eventLines.isEmpty ? noEventsText : eventLines)

        Today's reminders (\(reminderCount) total):
        \(reminderLines.isEmpty ? noRemindersText : reminderLines)\(pdfSection)

        IMPORTANT: Mention EVERY event and EVERY reminder listed above — do not skip any. Do not invent items not listed.
        \(langInstruction) Write \(length.maxSentences) sentence(s), but always include all events and reminders even if that requires more sentences.
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

        return """
        You are Lumio, a helpful and concise AI assistant for a morning briefing app. Answer the user's question based on their calendar and lecture notes. Be brief and direct.

        Today's calendar:
        \(eventLines.isEmpty ? noEventsText : eventLines)

        User question: \(question)

        \(langInstruction)
        """
    }

    // MARK: — Fallbacks (always work, no AI needed)

    func buildFallbackSummary(events: [CalendarEvent], reminders: [ReminderItem] = [], weather: WeatherData? = nil, language: String = "en") -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        var parts: [String] = []

        if let w = weather {
            if language == "de" {
                parts.append("\(w.conditionLabel), \(Int(w.temperatureCurrent.rounded()))°C.")
            } else {
                parts.append("\(w.conditionLabel), \(Int(w.temperatureCurrent.rounded()))°C.")
            }
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
                parts.append(String(localized: "You have a clear day today. Enjoy the focus time."))
            } else {
                if !events.isEmpty {
                    let eventList = events.map { "\($0.title) at \(fmt.string(from: $0.startDate))" }.joined(separator: ", ")
                    parts.append(events.count == 1
                        ? String(localized: "\(events[0].title) at \(fmt.string(from: events[0].startDate)) — that's your only event today.")
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
                ? String(localized: "You're free all day today.")
                : String(localized: "You're busy at: \(busy)")
        }
        if language == "de" {
            return "Ich kann dir bei Fragen zu deinem Kalender und deinen Notizen helfen. Zum Beispiel: \"Was habe ich heute?\" oder \"Bin ich um 15 Uhr frei?\""
        }
        return String(localized: "I can help you with questions about your calendar and lecture notes. For example: \"What do I have today?\" or \"Am I free at 3pm?\"")
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

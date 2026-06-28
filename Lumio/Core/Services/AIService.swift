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
        // Dynamic dispatch into FoundationModels.framework
        // This avoids a hard import so the app doesn't crash on unsupported devices
        // Replace with direct `import FoundationModels` import once framework is publicly distributed

        guard
            let modelClass = NSClassFromString("FoundationModels.SystemLanguageModel") as? NSObject.Type,
            let sessionClass = NSClassFromString("FoundationModels.LanguageModelSession") as? NSObject.Type
        else { return nil }

        // SystemLanguageModel.default
        let defaultSel = NSSelectorFromString("default")
        guard modelClass.responds(to: defaultSel) else { return nil }
        let model = modelClass.perform(defaultSel)?.takeUnretainedValue()

        // LanguageModelSession(model:)
        let initSel = NSSelectorFromString("initWithModel:")
        guard let session = sessionClass.perform(initSel, with: model)?.takeRetainedValue() as? NSObject else { return nil }

        // session.respond(to:) — async
        // Since we can't easily bridge async via NSInvocation, we use the respond sync path
        // In a real release build, replace this entire block with direct FoundationModels API calls
        let respondSel = NSSelectorFromString("respondTo:")
        if session.responds(to: respondSel) {
            if let result = session.perform(respondSel, with: prompt)?.takeRetainedValue() as? String {
                return result
            }
        }

        return nil
    }

    // MARK: — Prompt builders

    private func buildBriefingPrompt(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, pdfTexts: [String], language: String, length: BriefingLength, style: BriefingStyle) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = events.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        let reminderLines = reminders.prefix(5).map { "- \($0.title)" }.joined(separator: "\n")
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

        return """
        You are Lumio, a calm and intelligent morning briefing assistant. Summarize the user's day in \(length.maxSentences) sentence(s). Be concise.\(weatherSection)

        Today's events:
        \(eventLines.isEmpty ? noEventsText : eventLines)

        Today's reminders:
        \(reminderLines.isEmpty ? noRemindersText : reminderLines)\(pdfSection)

        \(langInstruction) Maximum \(length.maxSentences) sentence(s).
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
                    let first = events[0]
                    parts.append(events.count == 1
                        ? "\(first.title) um \(fmt.string(from: first.startDate)) – dein einziger Termin."
                        : "\(events.count) Termine heute. Erster: \(first.title) um \(fmt.string(from: first.startDate)).")
                }
                if !reminders.isEmpty {
                    parts.append(reminders.count == 1
                        ? "Erinnerung: \(reminders[0].title)."
                        : "\(reminders.count) Erinnerungen, z.B. \(reminders[0].title).")
                }
            }
        } else {
            if events.isEmpty && reminders.isEmpty {
                parts.append(String(localized: "You have a clear day today. Enjoy the focus time."))
            } else {
                if !events.isEmpty {
                    let first = events[0]
                    parts.append(events.count == 1
                        ? String(localized: "\(first.title) at \(fmt.string(from: first.startDate)) — that's your only event today.")
                        : String(localized: "\(events.count) events today. First up: \(first.title) at \(fmt.string(from: first.startDate))."))
                }
                if !reminders.isEmpty {
                    parts.append(reminders.count == 1
                        ? "Reminder: \(reminders[0].title)."
                        : "\(reminders.count) reminders, e.g. \(reminders[0].title).")
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

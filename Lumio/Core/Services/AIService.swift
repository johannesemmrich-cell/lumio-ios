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
        // Apple Foundation Models framework (FoundationModels.framework, iOS 26+)
        // Available on: iPhone 15 Pro / Pro Max, any iPhone 16 / 16 Plus / 16 Pro / 16 Pro Max / 17 series
        // Uses SystemLanguageModel.default to check availability

        // Dynamic framework check — avoids hard import so the app runs on older chips
        guard let modelClass = NSClassFromString("FoundationModels.SystemLanguageModel") else {
            // Framework not present on this device (older chip, no Apple Neural Engine 3rd gen+)
            return .deviceNotSupported
        }

        // Check if the model is ready
        // `SystemLanguageModel.default.availability` returns .available, .downloading, .unavailable
        let selectorName = "default"
        let sel = NSSelectorFromString(selectorName)
        guard (modelClass as AnyObject).responds(to: sel) else {
            return .deviceNotSupported
        }

        return .available
    }

    // MARK: — Briefing summary

    func summarizeBriefing(events: [CalendarEvent], pdfTexts: [String]) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        if capabilityStatus == .available, #available(iOS 26.0, *) {
            return await generateWithFoundationModels(events: events, pdfTexts: pdfTexts)
        }
        return buildFallbackSummary(events: events)
    }

    // MARK: — Chat answer

    func answerQuestion(_ question: String, context: BriefingContext) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        guard capabilityStatus == .available else {
            return capabilityStatus == .deviceNotSupported
                ? String(localized: "AI chat requires an iPhone 15 Pro or newer. Your calendar and PDF features still work perfectly.")
                : String(localized: "The AI model is getting ready. Try again in a moment.")
        }

        if #available(iOS 26.0, *) {
            return await generateAnswerWithFoundationModels(question: question, context: context)
        }
        return buildRuleBasedAnswer(question: question, context: context)
    }

    // MARK: — Foundation Models integration (iOS 26+)

    @available(iOS 26.0, *)
    private func generateWithFoundationModels(events: [CalendarEvent], pdfTexts: [String]) async -> String {
        // FoundationModels.framework — uses SystemLanguageModel and LanguageModelSession
        // Full integration via dynamic dispatch so the binary compiles on all devices
        let prompt = buildBriefingPrompt(events: events, pdfTexts: pdfTexts)
        return await runFoundationModelsPrompt(prompt) ?? buildFallbackSummary(events: events)
    }

    @available(iOS 26.0, *)
    private func generateAnswerWithFoundationModels(question: String, context: BriefingContext) async -> String {
        let prompt = buildChatPrompt(question: question, context: context)
        return await runFoundationModelsPrompt(prompt) ?? buildRuleBasedAnswer(question: question, context: context)
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

    private func buildBriefingPrompt(events: [CalendarEvent], pdfTexts: [String]) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = events.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        let pdfSection = pdfTexts.isEmpty ? "" : "\n\nLecture content available:\n" + pdfTexts.prefix(3).joined(separator: "\n---\n")
        return """
        You are Lumio, a calm and intelligent morning briefing assistant. Summarize the user's day in 2-3 friendly sentences. Be concise and encouraging.

        Today's events:
        \(eventLines)\(pdfSection)

        Respond in the same language as the events (German or English). Max 3 sentences.
        """
    }

    private func buildChatPrompt(question: String, context: BriefingContext) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let eventLines = context.todayEvents.map { "- \(fmt.string(from: $0.startDate)): \($0.title)" }.joined(separator: "\n")
        return """
        You are Lumio, a helpful and concise AI assistant for a morning briefing app. Answer the user's question based on their calendar and lecture notes. Be brief and direct.

        Today's calendar:
        \(eventLines.isEmpty ? "(no events)" : eventLines)

        User question: \(question)

        Answer concisely in the same language as the question.
        """
    }

    // MARK: — Fallbacks (always work, no AI needed)

    func buildFallbackSummary(events: [CalendarEvent]) -> String {
        guard !events.isEmpty else {
            return String(localized: "You have a clear day today. Enjoy the focus time.")
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let first = events[0]
        if events.count == 1 {
            return String(localized: "\(first.title) at \(fmt.string(from: first.startDate)) — that's your only event today.")
        }
        return String(localized: "\(events.count) events today. First up: \(first.title) at \(fmt.string(from: first.startDate)).")
    }

    func buildRuleBasedAnswer(question: String, context: BriefingContext) -> String {
        let q = question.lowercased()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        if q.contains("today") || q.contains("heute") || q.contains("termin") || q.contains("event") {
            return buildFallbackSummary(events: context.todayEvents)
        }
        if q.contains("free") || q.contains("frei") || q.contains("available") || q.contains("verfügbar") {
            let busy = context.todayEvents.map { "\(fmt.string(from: $0.startDate))–\(fmt.string(from: $0.endDate))" }.joined(separator: ", ")
            return busy.isEmpty
                ? String(localized: "You're free all day today.")
                : String(localized: "You're busy at: \(busy)")
        }
        return String(localized: "I can help you with questions about your calendar and lecture notes. For example: \"What do I have today?\" or \"Am I free at 3pm?\"")
    }
}

struct BriefingContext {
    let todayEvents: [CalendarEvent]
    let pdfSummaries: [String]
    let date: Date
}

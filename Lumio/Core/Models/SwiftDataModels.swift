import SwiftData
import Foundation
import SwiftUI

@Model
final class PDFFolder {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var documents: [PDFDocument]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.sortOrder = 0
        self.documents = []
    }

    var documentCount: Int { documents.count }
}

@Model
final class PDFDocument {
    var id: UUID
    var filename: String
    var originalFilename: String
    var uploadedAt: Date
    var pageCount: Int
    var fileSize: Int64
    var localPath: String
    var folder: PDFFolder?

    init(filename: String, originalFilename: String, pageCount: Int, fileSize: Int64, localPath: String) {
        self.id = UUID()
        self.filename = filename
        self.originalFilename = originalFilename
        self.uploadedAt = Date()
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.localPath = localPath
    }
}

@Model
final class FeedbackEntry {
    var id: UUID
    var timestamp: Date
    var screenContext: String
    var featureContext: String
    var elementContext: String
    var notes: String
    var priority: FeedbackPriority
    var isResolved: Bool

    init(screenContext: String, featureContext: String, elementContext: String, notes: String, priority: FeedbackPriority) {
        self.id = UUID()
        self.timestamp = Date()
        self.screenContext = screenContext
        self.featureContext = featureContext
        self.elementContext = elementContext
        self.notes = notes
        self.priority = priority
        self.isResolved = false
    }
}

enum FeedbackPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case testing = "Testing"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        case .testing: return "purple"
        }
    }

    var emoji: String {
        switch self {
        case .high: return "🔴"
        case .medium: return "🟠"
        case .low: return "🔵"
        case .testing: return "🟣"
        }
    }
}

@Model
final class UserPreferences {
    var id: UUID
    var notificationHour: Int
    var notificationMinute: Int
    var selectedTheme: String
    var selectedLanguage: String
    var briefingSectionOrder: [String]

    init() {
        self.id = UUID()
        self.notificationHour = 7
        self.notificationMinute = 30
        self.selectedTheme = AppTheme.system.rawValue
        self.selectedLanguage = Locale.current.language.languageCode?.identifier == "de" ? "de" : "en"
        self.briefingSectionOrder = BriefingSection.allCases.map(\.rawValue)
    }
}

enum BriefingSection: String, CaseIterable, Codable {
    case events = "events"
    case lectures = "lectures"
    case summary = "summary"
    case weather = "weather"

    var title: LocalizedStringKey {
        switch self {
        case .events: return "Calendar Events"
        case .lectures: return "Lecture Highlights"
        case .summary: return "AI Summary"
        case .weather: return "Weather"
        }
    }

    var icon: String {
        switch self {
        case .events: return "calendar"
        case .lectures: return "doc.text"
        case .summary: return "sparkles"
        case .weather: return "cloud.sun"
        }
    }
}

@Model
final class BriefingCache {
    var id: UUID
    var date: Date
    var summaryText: String
    var eventsJSON: Data
    var generatedAt: Date

    init(date: Date, summaryText: String, eventsJSON: Data) {
        self.id = UUID()
        self.date = date
        self.summaryText = summaryText
        self.eventsJSON = eventsJSON
        self.generatedAt = Date()
    }
}

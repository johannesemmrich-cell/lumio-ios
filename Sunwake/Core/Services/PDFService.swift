import PDFKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
final class PDFService: ObservableObject {
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var processingError: String?

    static let maxPDFsPerFolderFree = 5
    static let maxPagesPerPDFFree = 20
    static let documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    // language: the in-app language choice — the thrown error messages must
    // follow it, not the device language (String(localized:) would).
    func importPDF(from url: URL, into folder: PDFFolder, isPremium: Bool, language: String) async throws -> PDFDocument {
        isProcessing = true
        defer { isProcessing = false }

        let isDE = language == "de"

        guard url.startAccessingSecurityScopedResource() else {
            throw PDFError.accessDenied(isDE ? "Auf diese Datei kann nicht zugegriffen werden." : "Cannot access this file.")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if !isPremium && folder.documents.count >= Self.maxPDFsPerFolderFree {
            throw PDFError.limitReached(isDE
                ? "Der Free-Plan erlaubt bis zu 5 PDFs pro Ordner. Mit Premium gibt es keine Grenze."
                : "Free plan allows up to 5 PDFs per folder. Upgrade to Premium for unlimited PDFs.")
        }

        guard let pdfDoc = PDFKit.PDFDocument(url: url) else {
            throw PDFError.invalidFile(isDE ? "Diese Datei ist kein gültiges PDF." : "This file is not a valid PDF.")
        }

        let pageCount = pdfDoc.pageCount
        if !isPremium && pageCount > Self.maxPagesPerPDFFree {
            throw PDFError.limitReached(isDE
                ? "Der Free-Plan erlaubt PDFs bis 20 Seiten. Mit Premium gibt es keine Grenze."
                : "Free plan allows PDFs up to 20 pages. Upgrade to Premium for unlimited pages.")
        }

        let filename = "\(UUID().uuidString).pdf"
        let destinationURL = Self.documentsDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: url, to: destinationURL)

        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return PDFDocument(
            filename: filename,
            originalFilename: url.lastPathComponent,
            pageCount: pageCount,
            fileSize: fileSize,
            localPath: filename
        )
    }

    func extractText(from document: PDFDocument, maxPages: Int = 10) -> String {
        let url = Self.documentsDirectory.appendingPathComponent(document.localPath)
        guard let pdf = PDFKit.PDFDocument(url: url) else { return "" }
        var text = ""
        let pages = min(pdf.pageCount, maxPages)
        for i in 0..<pages {
            text += pdf.page(at: i)?.string ?? ""
            text += "\n"
        }
        return text
    }

    func pdfDocument(for document: PDFDocument) -> PDFKit.PDFDocument? {
        let url = Self.documentsDirectory.appendingPathComponent(document.localPath)
        return PDFKit.PDFDocument(url: url)
    }

    func deleteDocument(_ document: PDFDocument) throws {
        let url = Self.documentsDirectory.appendingPathComponent(document.localPath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// Each case carries its already-localized message, built at the throw site
// where the app language is known.
enum PDFError: LocalizedError {
    case accessDenied(String)
    case invalidFile(String)
    case limitReached(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let msg), .invalidFile(let msg), .limitReached(let msg):
            return msg
        }
    }
}

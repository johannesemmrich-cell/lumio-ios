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

    func importPDF(from url: URL, into folder: PDFFolder, isPremium: Bool) async throws -> PDFDocument {
        isProcessing = true
        defer { isProcessing = false }

        guard url.startAccessingSecurityScopedResource() else {
            throw PDFError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        if !isPremium && folder.documents.count >= Self.maxPDFsPerFolderFree {
            throw PDFError.limitReached(String(localized: "Free plan allows up to 5 PDFs per folder. Upgrade to Premium for unlimited PDFs."))
        }

        guard let pdfDoc = PDFKit.PDFDocument(url: url) else {
            throw PDFError.invalidFile
        }

        let pageCount = pdfDoc.pageCount
        if !isPremium && pageCount > Self.maxPagesPerPDFFree {
            throw PDFError.limitReached(String(localized: "Free plan allows PDFs up to 20 pages. Upgrade to Premium for unlimited pages."))
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

enum PDFError: LocalizedError {
    case accessDenied
    case invalidFile
    case limitReached(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied: return String(localized: "Cannot access this file.")
        case .invalidFile: return String(localized: "This file is not a valid PDF.")
        case .limitReached(let msg): return msg
        }
    }
}

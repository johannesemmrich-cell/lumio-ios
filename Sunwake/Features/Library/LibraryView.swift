import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PDFFolder.sortOrder) private var folders: [PDFFolder]

    @StateObject private var pdfService = PDFService()
    @State private var showNewFolderSheet = false
    @State private var selectedFolder: PDFFolder?
    @State private var showFilePicker = false
    @State private var importTargetFolder: PDFFolder?
    @State private var importError: String?
    @State private var showImportError = false

    var body: some View {
        NavigationStack {
            Group {
                if folders.isEmpty {
                    EmptyLibraryView { showNewFolderSheet = true }
                } else {
                    List {
                        ForEach(folders) { folder in
                            NavigationLink(destination: FolderDetailView(folder: folder)) {
                                FolderRow(folder: folder, accentColor: appState.accentColor)
                            }
                            .developerFeedbackOverlay(
                                isActive: appState.isDeveloperModeActive,
                                screen: "Library",
                                feature: "Folders",
                                element: "Folder: \(folder.name)"
                            )
                        }
                        .onDelete(perform: deleteFolders)
                        .onMove(perform: moveFolders)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewFolderSheet = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
                if appState.isDeveloperModeActive {
                    ToolbarItem(placement: .topBarLeading) {
                        DeveloperFeedbackButton(screen: "Library", feature: "Folders", element: "Toolbar")
                    }
                }
                if !folders.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet { name in
                addFolder(name: name)
            }
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func addFolder(name: String) {
        let folder = PDFFolder(name: name)
        folder.sortOrder = folders.count
        modelContext.insert(folder)
    }

    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            // Delete underlying files
            for doc in folder.documents {
                try? pdfService.deleteDocument(doc)
            }
            modelContext.delete(folder)
        }
    }

    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in reordered.enumerated() {
            folder.sortOrder = index
        }
    }
}

// MARK: — Folder Row

struct FolderRow: View {
    let folder: PDFFolder
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(SunwakeTypography.callout.weight(.semibold))
                Text("\(folder.documentCount) document\(folder.documentCount == 1 ? "" : "s")")
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: — Folder Detail

struct FolderDetailView: View {
    @Bindable var folder: PDFFolder
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var pdfService = PDFService()

    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var selectedDocument: PDFDocument?

    var body: some View {
        Group {
            if folder.documents.isEmpty {
                EmptyFolderView { showFilePicker = true }
            } else {
                List {
                    ForEach(folder.documents) { doc in
                        Button {
                            selectedDocument = doc
                        } label: {
                            DocumentRow(document: doc)
                        }
                        .buttonStyle(.plain)
                        .developerFeedbackOverlay(
                            isActive: appState.isDeveloperModeActive,
                            screen: "Library",
                            feature: "Documents",
                            element: "Document: \(doc.originalFilename)"
                        )
                    }
                    .onDelete(perform: deleteDocuments)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Library", feature: "Folder Detail", element: "Toolbar")
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleImport(result: result) }
        }
        .sheet(item: $selectedDocument) { doc in
            PDFPreviewView(document: doc)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func handleImport(result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let doc = try await pdfService.importPDF(
                from: url,
                into: folder,
                isPremium: subscriptionManager.effectivelyPremium
            )
            HapticFeedback.success()
            folder.documents.append(doc)
            modelContext.insert(doc)
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        let toDelete = offsets.map { folder.documents[$0] }
        for doc in toDelete {
            try? pdfService.deleteDocument(doc)
            modelContext.delete(doc)
            folder.documents.removeAll { $0.id == doc.id }
        }
    }
}

// MARK: — Document Row

struct DocumentRow: View {
    let document: PDFDocument

    private var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.fileSize)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext.fill")
                .font(.title2)
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(document.originalFilename)
                    .font(SunwakeTypography.callout.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text("\(document.pageCount) pages")
                    Text("·")
                    Text(fileSizeString)
                }
                .font(SunwakeTypography.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: — PDF Preview

struct PDFPreviewView: View {
    let document: PDFDocument
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pdfService = PDFService()

    var body: some View {
        NavigationStack {
            Group {
                if let pdfDoc = pdfService.pdfDocument(for: document) {
                    PDFKitView(document: pdfDoc)
                } else {
                    ContentUnavailableView("Cannot load PDF", systemImage: "doc.slash")
                }
            }
            .navigationTitle(document.originalFilename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: — PDFKit UIViewRepresentable

import PDFKit

struct PDFKitView: UIViewRepresentable {
    let document: PDFKit.PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// MARK: — New Folder Sheet

struct NewFolderSheet: View {
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Economics, Physics…", text: $name)
                        .focused($focused)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        HapticFeedback.success()
                        onAdd(name.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.fraction(0.3)])
    }
}

// MARK: — Empty states

struct EmptyLibraryView: View {
    let onCreateFolder: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Folders Yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Create a folder for each course or topic, then add your lecture PDFs.")
        } actions: {
            Button("Create Folder", action: onCreateFolder)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct EmptyFolderView: View {
    let onAddPDF: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No PDFs Yet", systemImage: "doc.badge.plus")
        } description: {
            Text("Add lecture slides or notes to this folder.")
        } actions: {
            Button("Add PDF", action: onAddPDF)
                .buttonStyle(.borderedProminent)
        }
    }
}

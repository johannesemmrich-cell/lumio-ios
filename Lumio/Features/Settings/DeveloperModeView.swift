import SwiftUI
import SwiftData
import CryptoKit

// MARK: — Unlock Sheet

struct DeveloperUnlockSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState

    @State private var password = ""
    @State private var error = ""
    @FocusState private var focused: Bool

    // SHA-256 of the developer password — password itself is never stored.
    private static let passwordHash = "686eb743564a96739741fd413b93b1a610fab0b2355248d8740a96c8032f5f11"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(appState.isDeveloperModeActive
                         ? "Passwort eingeben um den Entwicklermodus zu deaktivieren."
                         : "Passwort eingeben um den Entwicklermodus zu aktivieren.")
                        .font(LumioTypography.callout)
                        .foregroundStyle(.secondary)
                    SecureField("Passwort", text: $password)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if !error.isEmpty {
                    Section {
                        Text(error)
                            .font(LumioTypography.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Entwicklermodus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bestätigen") { handleSubmit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.fraction(0.4)])
    }

    private func handleSubmit() {
        guard checkPassword(password) else {
            error = "Falsches Passwort."
            password = ""
            return
        }
        let newState = !appState.isDeveloperModeActive
        appState.isDeveloperModeActive = newState
        UserDefaults.standard.set(newState, forKey: UserDefaultsKey.developerModeActive)
        isPresented = false
    }

    private func checkPassword(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let hash = SHA256.hash(data: Data(trimmed.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return hex == Self.passwordHash
    }
}

// MARK: — Developer Mode Main View

struct DeveloperModeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedbackEntry.timestamp, order: .reverse) private var feedbackEntries: [FeedbackEntry]
    @Query(sort: \DevTodoItem.createdAt, order: .forward) private var todoItems: [DevTodoItem]

    @State private var showAddTodo = false

    var body: some View {
        List {
            Section {
                Label("Developer Mode is active", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Label("All Premium features unlocked", systemImage: "star.fill")
                    .foregroundStyle(Color.lumioAccent)
            }

            Section("To-Do (\(todoItems.count))") {
                if todoItems.isEmpty {
                    Text("Noch keine Einträge.")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(todoItems) { item in
                    HStack(spacing: 12) {
                        Button {
                            item.isCompleted.toggle()
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        Text(item.title)
                            .font(LumioTypography.callout)
                            .strikethrough(item.isCompleted, color: .secondary)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(todoItems[index])
                    }
                }
                Button {
                    showAddTodo = true
                } label: {
                    Label("Neues To-Do", systemImage: "plus.circle")
                        .foregroundStyle(Color.lumioAccent)
                }
            }

            Section("Feedback Log (\(feedbackEntries.count))") {
                if feedbackEntries.isEmpty {
                    Text("No feedback entries yet. Tap 👎 on any element while Developer Mode is active.")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(feedbackEntries) { entry in
                        NavigationLink(destination: FeedbackEntryDetailView(entry: entry)) {
                            FeedbackEntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(feedbackEntries[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Developer Mode")
        .listStyle(.insetGrouped)
        .toolbar {
            if !feedbackEntries.isEmpty || !todoItems.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAddTodo) {
            AddDevTodoSheet(isPresented: $showAddTodo)
        }
    }
}

// MARK: — Add Todo Sheet

struct AddDevTodoSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $title)
                        .focused($focused)
                }
            }
            .navigationTitle("Neues To-Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hinzufügen") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        modelContext.insert(DevTodoItem(title: title.trimmingCharacters(in: .whitespaces)))
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.fraction(0.35)])
    }
}

struct FeedbackEntryRow: View {
    let entry: FeedbackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.screenContext)
                    .font(LumioTypography.caption.weight(.semibold))
                Text("›")
                    .foregroundStyle(.secondary)
                Text(entry.featureContext)
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.priority.emoji)
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(entry.timestamp, format: .dateTime.day().month().hour().minute())
                .font(LumioTypography.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct FeedbackEntryDetailView: View {
    @Bindable var entry: FeedbackEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Context") {
                LabeledContent("Screen", value: entry.screenContext)
                LabeledContent("Feature", value: entry.featureContext)
                LabeledContent("Element", value: entry.elementContext)
                LabeledContent("Time", value: entry.timestamp.formatted(.dateTime))
            }

            Section("Notes") {
                TextEditor(text: $entry.notes)
                    .frame(minHeight: 80)
            }

            Section("Priority") {
                Picker("Priority", selection: $entry.priority) {
                    ForEach(FeedbackPriority.allCases, id: \.self) { p in
                        Text("\(p.emoji) \(p.rawValue)").tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Feedback Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: — Feedback collection UI (thumbs down overlay)

struct DeveloperFeedbackButton: View {
    let screen: String
    let feature: String
    let element: String
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "hand.thumbsdown.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(5)
                .background(Circle().fill(Color.red.opacity(0.7)))
        }
        .sheet(isPresented: $showSheet) {
            FeedbackSubmitSheet(screen: screen, feature: feature, element: element)
        }
    }
}

struct FeedbackSubmitSheet: View {
    let screen: String
    let feature: String
    let element: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notes = ""
    @State private var priority: FeedbackPriority = .medium
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Context") {
                    LabeledContent("Screen", value: screen)
                    LabeledContent("Feature", value: feature)
                    LabeledContent("Element", value: element)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .focused($focused)
                        .frame(minHeight: 80)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(FeedbackPriority.allCases, id: \.self) { p in
                            Text("\(p.emoji) \(p.rawValue)").tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Submit Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        let entry = FeedbackEntry(
            screenContext: screen,
            featureContext: feature,
            elementContext: element,
            notes: notes,
            priority: priority
        )
        modelContext.insert(entry)
        dismiss()
    }
}

// MARK: — ViewModifier for developer feedback overlays

struct DeveloperFeedbackOverlay: ViewModifier {
    let isActive: Bool
    let screen: String
    let feature: String
    let element: String

    func body(content: Content) -> some View {
        if isActive {
            content.overlay(alignment: .topTrailing) {
                DeveloperFeedbackButton(screen: screen, feature: feature, element: element)
                    .padding(4)
            }
        } else {
            content
        }
    }
}

extension View {
    func developerFeedbackOverlay(isActive: Bool, screen: String, feature: String, element: String) -> some View {
        modifier(DeveloperFeedbackOverlay(isActive: isActive, screen: screen, feature: feature, element: element))
    }
}

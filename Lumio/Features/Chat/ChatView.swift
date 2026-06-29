import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            if !subscriptionManager.effectivelyPremium {
                ChatPaywallView()
            } else {
                chatContent
            }
        }
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .developerFeedbackOverlay(
                                    isActive: appState.isDeveloperModeActive,
                                    screen: "Chat",
                                    feature: "AI Chatbot",
                                    element: String(message.text.prefix(100))
                                )
                        }
                        if viewModel.isThinking {
                            ThinkingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()
            ChatInputBar(text: $viewModel.inputText, isThinking: viewModel.isThinking, focused: $inputFocused) {
                HapticFeedback.impact(.light)
                inputFocused = false
                Task { await viewModel.sendMessage() }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Chat", feature: "AI Chatbot", element: "Navigation")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { viewModel.clearHistory(language: appState.selectedLanguage) }
                    .foregroundStyle(.secondary)
            }
        }
        .task { await viewModel.setup(language: appState.selectedLanguage) }
        .onAppear {
            if let pending = appState.pendingBriefingForChat {
                viewModel.injectBriefingContext(pending, language: appState.selectedLanguage)
                appState.pendingBriefingForChat = nil
            }
        }
        .onChange(of: appState.pendingBriefingForChat) { _, pending in
            if let text = pending {
                viewModel.injectBriefingContext(text, language: appState.selectedLanguage)
                appState.pendingBriefingForChat = nil
            }
        }
    }
}

// MARK: — Message bubble

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date

    enum MessageRole { case user, assistant }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(LumioTypography.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser ? Color.lumioAccent : Color(uiColor: .secondarySystemBackground))
                    )
                    .foregroundStyle(isUser ? .white : .primary)

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(LumioTypography.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: phase == Double(i) ? -4 : 0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemBackground)))
            Spacer()
        }
        .onAppear { phase = 1 }
    }
}

// MARK: — Input bar

struct ChatInputBar: View {
    @Binding var text: String
    let isThinking: Bool
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask about your day…", text: $text, axis: .vertical)
                .font(LumioTypography.body)
                .focused(focused)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(uiColor: .secondarySystemBackground)))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty || isThinking ? Color.secondary : Color.lumioAccent)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: — Paywall for Chat

struct ChatPaywallView: View {
    var body: some View {
        ContentUnavailableView {
            Label("AI Chat is Premium", systemImage: "bubble.left.and.sparkles")
        } description: {
            Text("Ask your AI assistant about your schedule, lecture notes, or anything on your mind. Available with Lumio Premium.")
        } actions: {
            NavigationLink(destination: PaywallView()) {
                Text("Unlock Premium")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

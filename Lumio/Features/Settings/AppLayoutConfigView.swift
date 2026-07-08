import SwiftUI

private struct SlotID: Identifiable { let id: Int }

// MARK: — TopBarAction

enum TopBarAction: String, CaseIterable {
    case calendar = "calendar"
    case chat = "chat_shortcut"
    case refresh = "refresh"
    case library = "library"
    case settings = "settings"
    case none = "none"

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .chat:     return "bubble.left.fill"
        case .refresh:  return "arrow.clockwise"
        case .library:  return "books.vertical.fill"
        case .settings: return "gearshape.fill"
        case .none:     return "minus"
        }
    }

    var label: String {
        switch self {
        case .calendar: return "Kalender"
        case .chat:     return "Chat"
        case .refresh:  return "Aktualisieren"
        case .library:  return "Mediathek"
        case .settings: return "Einstellungen"
        case .none:     return "Leer"
        }
    }
}

// MARK: — AppLayoutConfigView

struct AppLayoutConfigView: View {
    @EnvironmentObject private var appState: AppState

    @State private var slot0: AppTab = .today
    @State private var slot1: AppTab = .library
    @State private var slot2: AppTab = .chat
    @State private var slot3: AppTab = .settings
    @State private var editingSlot: SlotID? = nil

    @State private var topSlot0: TopBarAction = .calendar
    @State private var topSlot1: TopBarAction = .refresh
    @State private var editingTopSlot: SlotID? = nil
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                phonePreview
                accentColorSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("App-Layout")
        .tint(appState.accentColor)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Zurücksetzen") { showResetConfirmation = true }
                    .font(LumioTypography.body)
            }
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Settings", feature: "App Layout", element: "Toolbar")
                }
            }
        }
        .confirmationDialog("Design zurücksetzen?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Auf Standard zurücksetzen", role: .destructive) {
                HapticFeedback.impact(.medium)
                withAnimation(.spring(duration: 0.3)) {
                    appState.accentColorHex = "FF9500"
                    appState.topBarActions = ["calendar", "refresh"]
                    appState.tabOrder = AppTab.allCases
                    loadSlots()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Akzentfarbe, Tab-Reihenfolge und Toolbar-Aktionen werden auf die Standardwerte zurückgesetzt.")
        }
        .onAppear { loadSlots() }
        .sheet(item: $editingSlot) { slot in
            TabPickerSheet(
                currentTab: currentSlots[slot.id],
                onSelect: { newTab in
                    let oldSlots = [slot0, slot1, slot2, slot3]
                    let index = slot.id
                    var newSlots = oldSlots
                    if let existingIndex = oldSlots.firstIndex(of: newTab), existingIndex != index {
                        newSlots[existingIndex] = oldSlots[index]
                    }
                    newSlots[index] = newTab
                    withAnimation(.spring(duration: 0.2)) {
                        slot0 = newSlots[0]; slot1 = newSlots[1]
                        slot2 = newSlots[2]; slot3 = newSlots[3]
                        appState.tabOrder = newSlots
                    }
                    editingSlot = nil
                }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(item: $editingTopSlot) { slot in
            TopBarPickerSheet(
                currentAction: slot.id == 0 ? topSlot0 : topSlot1,
                onSelect: { action in
                    withAnimation(.spring(duration: 0.2)) {
                        if slot.id == 0 { topSlot0 = action } else { topSlot1 = action }
                        appState.topBarActions = [topSlot0.rawValue, topSlot1.rawValue]
                    }
                    editingTopSlot = nil
                }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    // MARK: — Phone preview

    private var phonePreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vorschau")
                    .font(LumioTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tippe auf einen Tab")
                    .font(LumioTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 12)

            ZStack(alignment: .bottom) {
                // Phone frame
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 200, height: 360)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

                // Screen
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 188, height: 352)

                VStack(spacing: 0) {
                    // Dynamic Island
                    Capsule()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: 60, height: 10)
                        .padding(.top, 10)

                    // Top bar area with configurable action buttons
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            topSlotButton(index: 0)
                            topSlotButton(index: 1)
                        }
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                    }

                    // Content placeholders
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(height: 36)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.06))
                            .frame(height: 20)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.06))
                            .frame(height: 20)
                            .padding(.trailing, 40)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.05))
                            .frame(height: 20)
                            .padding(.trailing, 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Interactive tab bar
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { index in
                            tabSlotButton(index: index)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 6)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 0.5),
                                alignment: .top
                            )
                    )
                }
                .frame(width: 188, height: 352)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func topSlotButton(index: Int) -> some View {
        let action = index == 0 ? topSlot0 : topSlot1
        Button {
            editingTopSlot = SlotID(id: index)
        } label: {
            Image(systemName: action.icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(appState.accentColor)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(appState.accentColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabSlotButton(index: Int) -> some View {
        let tab = currentSlots[index]
        let color = appState.accentColor
        Button {
            editingSlot = SlotID(id: index)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 20)
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(tab.shortLabel)
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(color.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: — Accent color

    private var accentColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Akzentfarbe", icon: "paintpalette.fill")
            ColorPaletteGrid(selectedHex: $appState.accentColorHex)
        }
    }

    // MARK: — Helpers

    private var currentSlots: [AppTab] { [slot0, slot1, slot2, slot3] }

    private func setSlot(_ index: Int, to tab: AppTab) {
        switch index {
        case 0: slot0 = tab
        case 1: slot1 = tab
        case 2: slot2 = tab
        default: slot3 = tab
        }
    }

    private func loadSlots() {
        let order = appState.tabOrder
        slot0 = order.indices.contains(0) ? order[0] : .today
        slot1 = order.indices.contains(1) ? order[1] : .library
        slot2 = order.indices.contains(2) ? order[2] : .chat
        slot3 = order.indices.contains(3) ? order[3] : .settings

        let actions = appState.topBarActions
        topSlot0 = TopBarAction(rawValue: actions.indices.contains(0) ? actions[0] : "calendar") ?? .calendar
        topSlot1 = TopBarAction(rawValue: actions.indices.contains(1) ? actions[1] : "refresh") ?? .refresh
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(LumioTypography.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.top, 4)
    }
}

// MARK: — Tab Picker Sheet

private struct TabPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let currentTab: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Tab auswählen")
                .font(LumioTypography.headline.weight(.semibold))
                .padding(.top, 24)
                .padding(.bottom, 16)

            VStack(spacing: 1) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    let isPremiumLocked = tab == .calendar && !subscriptionManager.effectivelyPremium
                    Button {
                        guard !isPremiumLocked else { return }
                        HapticFeedback.selection()
                        onSelect(tab)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tab == currentTab
                                          ? appState.accentColor
                                          : Color.secondary.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: tab.icon)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(tab == currentTab ? .white : (isPremiumLocked ? .secondary : .primary))
                            }

                            Text(tab.fullLabel)
                                .font(LumioTypography.body)
                                .foregroundStyle(isPremiumLocked ? .secondary : .primary)

                            Spacer()

                            if isPremiumLocked {
                                Text("Premium")
                                    .font(LumioTypography.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.lumioAccent))
                            } else if tab == currentTab {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(appState.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: — Top Bar Picker Sheet

private struct TopBarPickerSheet: View {
    @EnvironmentObject private var appState: AppState
    let currentAction: TopBarAction
    let onSelect: (TopBarAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Toolbar-Aktion auswählen")
                .font(LumioTypography.headline.weight(.semibold))
                .padding(.top, 24)
                .padding(.bottom, 16)

            VStack(spacing: 1) {
                ForEach(TopBarAction.allCases, id: \.self) { action in
                    Button { HapticFeedback.selection(); onSelect(action) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(action == currentAction
                                          ? appState.accentColor
                                          : Color.secondary.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: action.icon)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(action == currentAction ? .white : .primary)
                            }
                            Text(action.label)
                                .font(LumioTypography.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if action == currentAction {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(appState.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: — Color Palette Grid

private struct ColorPaletteGrid: View {
    @Binding var selectedHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(lumioAccentPalette, id: \.hex) { item in
                let isSelected = selectedHex == item.hex
                VStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: item.hex))
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(hex: item.hex).opacity(0.4), radius: 6, y: 3)
                        .overlay(
                            Circle().strokeBorder(isSelected ? Color.primary.opacity(0.4) : Color.clear, lineWidth: 2.5)
                        )
                        .overlay(
                            isSelected ? Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white) : nil
                        )
                        .animation(.spring(duration: 0.2), value: isSelected)

                    Text(item.label)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                .onTapGesture {
                    HapticFeedback.selection()
                    withAnimation(.spring(duration: 0.2)) { selectedHex = item.hex }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: — AppTab helpers

private extension AppTab {
    var shortLabel: String {
        switch self {
        case .today:    return "Heute"
        case .calendar: return "Kalender"
        case .library:  return "Mediathek"
        case .chat:     return "Chat"
        case .settings: return "Einst."
        }
    }

    var fullLabel: String {
        switch self {
        case .today:    return "Heute"
        case .calendar: return "Kalender"
        case .library:  return "Mediathek"
        case .chat:     return "Chat"
        case .settings: return "Einstellungen"
        }
    }
}

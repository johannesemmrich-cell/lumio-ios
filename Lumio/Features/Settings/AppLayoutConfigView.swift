import SwiftUI

struct AppLayoutConfigView: View {
    @EnvironmentObject private var appState: AppState

    // Local copies for the pickers (so order is enforced unique)
    @State private var slot0: AppTab = .today
    @State private var slot1: AppTab = .library
    @State private var slot2: AppTab = .chat
    @State private var slot3: AppTab = .settings

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                phonePreview
                tabPositionsSection
                accentColorSection
                tabIconColorsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("App-Layout")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadSlots() }
    }

    // MARK: — Phone preview

    private var phonePreview: some View {
        VStack(spacing: 0) {
            Text("Vorschau")
                .font(LumioTypography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ZStack(alignment: .bottom) {
                // Phone frame
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 200, height: 360)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

                // Screen clip
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 188, height: 352)

                // Inner content (simplified)
                VStack(spacing: 0) {
                    // Notch / Dynamic Island
                    Capsule()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: 60, height: 10)
                        .padding(.top, 10)

                    // Content area
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()

                    // Tab bar mockup
                    HStack(spacing: 0) {
                        ForEach(currentSlots, id: \.self) { tab in
                            VStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 17, weight: .medium))
                                Text(tab.shortLabel)
                                    .font(.system(size: 7, weight: .medium))
                            }
                            .foregroundStyle(appState.iconColor(for: tab))
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 6)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 0.5), alignment: .top)
                    )
                }
                .frame(width: 188, height: 352)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
    }

    // MARK: — Tab positions

    private var tabPositionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Tab-Positionen", icon: "rectangle.grid.1x2")

            VStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { index in
                    tabPositionRow(index: index)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func tabPositionRow(index: Int) -> some View {
        let binding = slotBinding(index)
        HStack(spacing: 14) {
            Text("Position \(index + 1)")
                .font(LumioTypography.callout)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Picker("Position \(index + 1)", selection: binding) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Label(tab.fullLabel, systemImage: tab.icon).tag(tab)
                }
            }
            .labelsHidden()
            .tint(appState.iconColor(for: binding.wrappedValue))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: — Accent color

    private var accentColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Akzentfarbe", icon: "paintpalette.fill")

            ColorPaletteGrid(selectedHex: $appState.accentColorHex)
        }
    }

    // MARK: — Tab icon colors

    private var tabIconColorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Tab-Icon-Farben", icon: "square.grid.2x2")

            VStack(spacing: 1) {
                ForEach(currentSlots, id: \.self) { tab in
                    tabIconColorRow(tab: tab)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func tabIconColorRow(tab: AppTab) -> some View {
        let currentHex = appState.tabIconColorHexes[tab.rawValue] ?? appState.accentColorHex
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(appState.iconColor(for: tab))
                    .frame(width: 24)
                Text(tab.fullLabel)
                    .font(LumioTypography.callout)
                Spacer()
                Button {
                    appState.tabIconColorHexes.removeValue(forKey: tab.rawValue)
                } label: {
                    Text("Reset")
                        .font(LumioTypography.caption)
                        .foregroundStyle(appState.tabIconColorHexes[tab.rawValue] == nil ? .tertiary : .secondary)
                }
                .disabled(appState.tabIconColorHexes[tab.rawValue] == nil)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lumioAccentPalette, id: \.hex) { item in
                        let isSelected = currentHex == item.hex
                        Circle()
                            .fill(Color(hex: item.hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                                    .padding(2)
                            )
                            .overlay(
                                isSelected ? Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white) : nil
                            )
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.2)) {
                                    appState.tabIconColorHexes[tab.rawValue] = item.hex
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: — Helpers

    private var currentSlots: [AppTab] { [slot0, slot1, slot2, slot3] }

    private func slotBinding(_ index: Int) -> Binding<AppTab> {
        Binding(
            get: {
                switch index {
                case 0: return slot0
                case 1: return slot1
                case 2: return slot2
                default: return slot3
                }
            },
            set: { newTab in
                // Swap if newTab already exists in another slot
                let slots = [slot0, slot1, slot2, slot3]
                if let existingIndex = slots.firstIndex(of: newTab), existingIndex != index {
                    let displaced = slots[index]
                    setSlot(existingIndex, to: displaced)
                }
                setSlot(index, to: newTab)
                appState.tabOrder = [slot0, slot1, slot2, slot3]
            }
        )
    }

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
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(LumioTypography.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
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
        case .library:  return "Mediathek"
        case .chat:     return "Chat"
        case .settings: return "Einst."
        }
    }

    var fullLabel: String {
        switch self {
        case .today:    return "Heute"
        case .library:  return "Mediathek"
        case .chat:     return "Chat"
        case .settings: return "Einstellungen"
        }
    }
}

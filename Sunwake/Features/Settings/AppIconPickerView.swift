import SwiftUI
import UIKit

struct AppIconOption: Identifiable {
    let id: String
    let name: String?          // nil = default icon
    let label: String
    let symbol: String
    let colors: [Color]
}

private let iconOptions: [AppIconOption] = [
    AppIconOption(id: "default",   name: nil,                  label: "Sunwake",    symbol: "sun.max.fill",      colors: [Color(hex: 0xFF9500), Color(hex: 0xFF3B30)]),
    AppIconOption(id: "dawn",      name: "AppIcon-Dawn",       label: "Dawn",     symbol: "sunrise.fill",      colors: [Color(hex: 0xFF2D78), Color(hex: 0xFF9A3C)]),
    AppIconOption(id: "midnight",  name: "AppIcon-Midnight",   label: "Midnight", symbol: "moon.stars.fill",   colors: [Color(hex: 0x0D1B2A), Color(hex: 0x1A237E)]),
    AppIconOption(id: "forest",    name: "AppIcon-Forest",     label: "Forest",   symbol: "leaf.fill",         colors: [Color(hex: 0x1B5E20), Color(hex: 0x43A047)]),
    AppIconOption(id: "ocean",     name: "AppIcon-Ocean",      label: "Ocean",    symbol: "water.waves",       colors: [Color(hex: 0x01579B), Color(hex: 0x039BE5)]),
    // Neutral icons
    AppIconOption(id: "slate",     name: "AppIcon-Slate",      label: "Slate",    symbol: "square.fill",       colors: [Color(hex: 0x3A3A3C), Color(hex: 0x1C1C1E)]),
    AppIconOption(id: "minimal",   name: "AppIcon-Minimal",    label: "Minimal",  symbol: "circle.fill",       colors: [Color(hex: 0xE5E5EA), Color(hex: 0xC7C7CC)]),
]

struct AppIconPickerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    @State private var isChanging = false
    @State private var errorMessage: String? = nil

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(iconOptions) { option in
                    IconCell(
                        option: option,
                        isSelected: currentIconName == option.name,
                        isChanging: isChanging
                    ) {
                        applyIcon(option)
                    }
                }
            }
            .padding(20)

            if let error = errorMessage {
                Text(error)
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("App-Icon")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if appState.isDeveloperModeActive {
                ToolbarItem(placement: .topBarLeading) {
                    DeveloperFeedbackButton(screen: "Settings", feature: "App Icon Picker", element: "Toolbar")
                }
            }
        }
    }

    private func applyIcon(_ option: AppIconOption) {
        guard !isChanging else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Dein Gerät unterstützt keine alternativen App-Icons."
            return
        }
        HapticFeedback.impact(.medium)
        isChanging = true
        errorMessage = nil
        UIApplication.shared.setAlternateIconName(option.name) { error in
            DispatchQueue.main.async {
                isChanging = false
                if let error {
                    HapticFeedback.error()
                    errorMessage = error.localizedDescription
                } else {
                    HapticFeedback.success()
                    currentIconName = option.name
                }
            }
        }
    }
}

private struct IconCell: View {
    @EnvironmentObject private var appState: AppState

    let option: AppIconOption
    let isSelected: Bool
    let isChanging: Bool
    let action: () -> Void

    private var iconImage: UIImage? {
        // Use dedicated preview imagesets (reliable via UIImage(named:))
        if let name = option.name {
            let previewName = "\(name)-preview"
            if let img = UIImage(named: previewName) { return img }
        }
        // Default icon: UIImage(named:) works for the primary AppIcon
        if let img = UIImage(named: "AppIcon") { return img }
        return nil
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Group {
                    if let image = iconImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(LinearGradient(colors: option.colors, startPoint: .top, endPoint: .bottom))
                            .frame(width: 76, height: 76)
                            .overlay {
                                Image(systemName: option.symbol)
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .symbolRenderingMode(.hierarchical)
                            }
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(isSelected ? appState.accentColor : Color.clear, lineWidth: 3)
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(appState.accentColor)
                            .background(Circle().fill(Color(uiColor: .systemBackground)).padding(2))
                            .offset(x: 4, y: 4)
                    }
                }

                Text(option.label)
                    .font(SunwakeTypography.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: — Color helper

private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex         & 0xFF) / 255.0
        )
    }
}

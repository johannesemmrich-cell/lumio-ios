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
    AppIconOption(id: "default",   name: nil,                label: "Lumio",    symbol: "sun.max.fill",      colors: [Color(hex: 0xFF9500), Color(hex: 0xFF3B30)]),
    AppIconOption(id: "dawn",      name: "AppIcon-Dawn",     label: "Dawn",     symbol: "sunrise.fill",      colors: [Color(hex: 0xFF2D78), Color(hex: 0xFF9A3C)]),
    AppIconOption(id: "midnight",  name: "AppIcon-Midnight", label: "Midnight", symbol: "moon.stars.fill",   colors: [Color(hex: 0x0D1B2A), Color(hex: 0x1A237E)]),
    AppIconOption(id: "forest",    name: "AppIcon-Forest",   label: "Forest",   symbol: "leaf.fill",         colors: [Color(hex: 0x1B5E20), Color(hex: 0x43A047)]),
    AppIconOption(id: "ocean",     name: "AppIcon-Ocean",    label: "Ocean",    symbol: "water.waves",       colors: [Color(hex: 0x01579B), Color(hex: 0x039BE5)]),
]

struct AppIconPickerView: View {
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
                    .font(LumioTypography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("App-Icon")
        .navigationBarTitleDisplayMode(.large)
    }

    private func applyIcon(_ option: AppIconOption) {
        guard !isChanging else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Dein Gerät unterstützt keine alternativen App-Icons."
            return
        }
        isChanging = true
        errorMessage = nil
        UIApplication.shared.setAlternateIconName(option.name) { error in
            DispatchQueue.main.async {
                isChanging = false
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    currentIconName = option.name
                }
            }
        }
    }
}

private struct IconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let isChanging: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: option.colors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: option.colors.last?.opacity(0.4) ?? .clear, radius: 8, y: 4)

                    Image(systemName: option.symbol)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .symbolRenderingMode(.hierarchical)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.accentColor)
                            .background(Circle().fill(Color(uiColor: .systemBackground)).padding(2))
                            .offset(x: 4, y: 4)
                    }
                }

                Text(option.label)
                    .font(LumioTypography.caption.weight(isSelected ? .semibold : .regular))
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

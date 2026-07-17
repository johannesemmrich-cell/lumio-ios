import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID = SubscriptionManager.yearlyProductID
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .symbolEffect(.bounce)

                        Text("Sunwake Premium")
                            .font(SunwakeTypography.hero)

                        Text("Unlock the full morning briefing experience")
                            .font(SunwakeTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Product picker (with prices)
                    VStack(spacing: 10) {
                        if subscriptionManager.products.isEmpty {
                            VStack(spacing: 10) {
                                ProductPlaceholderRow(title: "Jährlich", price: "19,99 €/Jahr", subtitle: "1,67 €/Monat", isBest: true, isSelected: selectedProductID == SubscriptionManager.yearlyProductID) {
                                    selectedProductID = SubscriptionManager.yearlyProductID
                                }
                                ProductPlaceholderRow(title: "Monatlich", price: "2,99 €/Monat", subtitle: nil, isBest: false, isSelected: selectedProductID == SubscriptionManager.monthlyProductID) {
                                    selectedProductID = SubscriptionManager.monthlyProductID
                                }
                            }
                        } else {
                            ForEach(subscriptionManager.products) { product in
                                ProductOptionRow(
                                    product: product,
                                    isSelected: selectedProductID == product.id,
                                    isBestValue: product.id == SubscriptionManager.yearlyProductID
                                ) {
                                    selectedProductID = product.id
                                }
                            }
                        }
                    }

                    // Purchase button
                    VStack(spacing: 12) {
                        Button {
                            Task { await purchase() }
                        } label: {
                            Group {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Get Premium")
                                        .font(SunwakeTypography.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(appState.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isPurchasing)

                        if let error = purchaseError {
                            Text(error)
                                .font(SunwakeTypography.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button("Restore Purchases") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Free vs Premium comparison table
                    comparisonTable

                    Text("Prices in EUR. Payment via Apple ID. Subscription auto-renews unless cancelled.")
                        .font(SunwakeTypography.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(appState.accentColor)
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Funktion")
                    .font(SunwakeTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(SunwakeTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .center)
                Text("Premium")
                    .font(SunwakeTypography.caption.weight(.bold))
                    .foregroundStyle(appState.accentColor)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 14)

            comparisonRow("Kalender",           free: "1",           premium: "Mehrere")
            comparisonRow("PDFs",               free: "5/Ordner",    premium: "Unbegrenzt")
            comparisonRow("Vorlesen",           free: "Termine",     premium: "Alles")
            comparisonRow("KI-Chatbot",         free: nil,           premium: "✓")
            comparisonRow("Briefing-Länge",     free: nil,           premium: "✓")
            comparisonRow("Tab-Reihenfolge",    free: nil,           premium: "✓")
            comparisonRow("App-Icons",          free: nil,           premium: "✓")
            comparisonRow("Widget",             free: nil,           premium: "✓")
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
    }

    private func comparisonRow(_ feature: LocalizedStringKey, free: String?, premium: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(SunwakeTypography.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    if let free {
                        Text(free)
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                    }
                }
                .frame(width: 56, alignment: .center)
                Text(premium)
                    .font(SunwakeTypography.caption.weight(.semibold))
                    .foregroundStyle(premium == "✓" ? Color.green : appState.accentColor)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider().padding(.horizontal, 14)
        }
    }

    private func purchase() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await subscriptionManager.purchase(product)
            dismiss()
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

struct ProductPlaceholderRow: View {
    @EnvironmentObject private var appState: AppState

    let title: String
    let price: String
    let subtitle: String?
    let isBest: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(SunwakeTypography.callout.weight(.semibold))
                        if isBest {
                            Text("Best value")
                                .font(SunwakeTypography.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(price)
                    .font(SunwakeTypography.callout.weight(.bold))
                    .foregroundStyle(isSelected ? appState.accentColor : .primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? appState.accentColor.opacity(0.08) : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? appState.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let color: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(SunwakeTypography.callout)
        }
    }
}

struct ProductOptionRow: View {
    @EnvironmentObject private var appState: AppState

    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(SunwakeTypography.callout.weight(.semibold))
                        if isBestValue {
                            Text("Best value")
                                .font(SunwakeTypography.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    Text(product.description)
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(SunwakeTypography.callout.weight(.bold))
                    .foregroundStyle(isSelected ? appState.accentColor : .primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? appState.accentColor.opacity(0.08) : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? appState.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

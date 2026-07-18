import SwiftUI

/// Shows the user's premium background photo behind a tab's content.
/// No-op when no photo is set or the user isn't premium, so every tab keeps
/// its default look. A system-background scrim keeps text readable and adapts
/// to light/dark mode.
struct SunwakeTabBackgroundModifier: ViewModifier {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    func body(content: Content) -> some View {
        if let image = appState.tabBackgroundImage, subscriptionManager.effectivelyPremium {
            content
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                        Color(uiColor: .systemBackground).opacity(0.62)
                    }
                    .ignoresSafeArea()
                }
        } else {
            content
        }
    }
}

extension View {
    /// Apply at the root of each tab's content (inside its NavigationStack).
    func sunwakeTabBackground() -> some View {
        modifier(SunwakeTabBackgroundModifier())
    }
}

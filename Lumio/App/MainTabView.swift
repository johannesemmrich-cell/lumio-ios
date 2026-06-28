import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(appState.tabOrder, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    tabContent(for: tab)
                        .tint(appState.accentColor)
                }
            }
        }
        .onChange(of: appState.selectedTab) {
            HapticFeedback.selection()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayView()
        case .calendar:
            NavigationStack { LumioCalendarView() }
        case .library:
            LibraryView()
        case .chat:
            ChatView()
                .overlay(alignment: .topTrailing) {
                    if !subscriptionManager.effectivelyPremium {
                        PremiumBadge().padding(8)
                    }
                }
        case .settings:
            SettingsView()
        }
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("Premium")
            .font(LumioTypography.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.lumioAccent))
    }
}

import SwiftUI

struct TabOrderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                ForEach(appState.tabOrder, id: \.self) { tab in
                    HStack(spacing: 14) {
                        Image(systemName: tab.icon)
                            .font(.body.weight(.medium))
                            .foregroundStyle(appState.accentColor)
                            .frame(width: 28)
                        Text(tab.title)
                            .font(SunwakeTypography.body)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                    }
                }
                .onMove { source, destination in
                    appState.tabOrder.move(fromOffsets: source, toOffset: destination)
                }
            } footer: {
                Text("Ziehe die Tabs in die gewünschte Reihenfolge. Die Änderung gilt sofort.")
                    .font(SunwakeTypography.caption)
            }
        }
        .navigationTitle("Tab-Reihenfolge")
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
    }
}

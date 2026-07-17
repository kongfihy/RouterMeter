import SwiftUI
import OpenRouterMonitorCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tuningfork")
                .font(.system(size: 11, weight: .semibold))
                .imageScale(.small)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Brand.accent)
                .frame(width: 13, height: 13)
                .accessibilityHidden(true)

            Text(title)
                .monospacedDigit()
                .animatedNumericText(value: title)
        }
            .task {
                await store.start()
            }
    }

    private var title: String {
        return MenuBarTitleBuilder.title(
            snapshot: store.latestSnapshot,
            mode: store.state.configuration.menuBarMode,
            moneyFormatter: store.moneyFormatter,
            todaySpendOverride: store.currentLocalDayUsage?.usage
        )
    }
}

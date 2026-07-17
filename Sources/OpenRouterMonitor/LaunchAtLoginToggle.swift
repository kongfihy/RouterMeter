import SwiftUI

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = LaunchAtLoginManager.isEnabled
    @State private var statusText = LaunchAtLoginManager.statusDescription
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch RouterMeter at login", isOn: launchBinding)

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Spacer()
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Brand.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: refresh)
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                do {
                    try LaunchAtLoginManager.setEnabled(newValue)
                    errorText = nil
                } catch {
                    errorText = error.localizedDescription
                }
                refresh()
            }
        )
    }

    private var statusColor: Color {
        if statusText == "Enabled" {
            return Brand.accentSecondary
        }
        if statusText.contains("approval") {
            return Brand.warning
        }
        return .secondary
    }

    private func refresh() {
        isEnabled = LaunchAtLoginManager.isEnabled
        statusText = LaunchAtLoginManager.statusDescription
    }
}

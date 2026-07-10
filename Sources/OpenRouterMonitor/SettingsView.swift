import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OpenRouterMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var apiKey = ""
    @State private var trackedModelID = ""
    @State private var showRemoveKeyConfirmation = false
    @State private var notificationTestMessage: String?
    @State private var exportMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader
                apiKeySection

                HStack(alignment: .top, spacing: 16) {
                    startupSection
                    refreshSection
                }

                trackedModelsSection

                HStack(alignment: .top, spacing: 16) {
                    budgetSection
                    currencySection
                }

                notificationsSection
                dataAndStatusSection
            }
            .padding(24)
        }
        .scrollIndicators(.visible)
        .frame(width: 720, height: 760)
        .background(Brand.windowBackground)
        .foregroundStyle(.primary)
        .tint(Brand.accent)
        .task {
            async let catalog: Void = store.refreshModelCatalogIfNeeded()
            async let notifications: Void = store.refreshNotificationAuthorizationStatus()
            _ = await (catalog, notifications)
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            BrandIcon(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("OpenRouter access, display, budgets, and notifications")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(
                title: store.connectionState.label,
                systemImage: connectionStatusImage,
                color: connectionStatusColor
            )
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var apiKeySection: some View {
        SettingsCard(title: "OpenRouter API Key", systemImage: "key.horizontal") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Keys are validated before being stored in Apple Keychain. Account analytics access is detected automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("API key") {
                    SecureField(store.storedAPIKeyPlaceholder(), text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 430)
                        .accessibilityLabel("OpenRouter API key")
                }

                LabeledContent("Analytics access") {
                    StatusBadge(
                        title: store.state.profile.isManagementKey ? "Account + activity" : "Key-level usage",
                        systemImage: store.state.profile.isManagementKey ? "checkmark.circle.fill" : "info.circle.fill",
                        color: store.state.profile.isManagementKey ? Brand.accentSecondary : .secondary
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            if await store.validateAndSaveAPIKey(apiKey) {
                                apiKey = ""
                            }
                        }
                    } label: {
                        if store.isValidatingAPIKey {
                            Label("Validating", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Validate & Save", systemImage: "checkmark.shield")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isValidatingAPIKey)

                    Button("Remove Key", systemImage: "trash", role: .destructive) {
                        showRemoveKeyConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.state.profile.hasStoredKey)

                    Spacer()
                }

                if let message = store.apiKeyValidationMessage {
                    Label(
                        message,
                        systemImage: store.apiKeyValidationSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(store.apiKeyValidationSucceeded ? Brand.accentSecondary : Brand.warning)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog(
            "Remove the OpenRouter API key?",
            isPresented: $showRemoveKeyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Key", role: .destructive) {
                apiKey = ""
                store.removeAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The key will be deleted from Apple Keychain. Cached usage data will remain on this Mac.")
        }
    }

    private var startupSection: some View {
        SettingsCard(title: "Startup", systemImage: "power") {
            LaunchAtLoginToggle()
        }
        .frame(maxWidth: .infinity)
    }

    private var refreshSection: some View {
        SettingsCard(title: "Refresh", systemImage: "arrow.clockwise") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Menu bar") {
                    Picker("Menu bar display", selection: $store.state.configuration.menuBarModeRawValue) {
                        ForEach(MenuBarDisplayMode.allCases, id: \.rawValue) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: store.state.configuration.menuBarModeRawValue) { _, _ in store.save() }
                }

                LabeledContent("Interval") {
                    Stepper(
                        "Every \(Int(store.state.configuration.refreshIntervalMinutes)) min",
                        value: $store.state.configuration.refreshIntervalMinutes,
                        in: 1...60,
                        step: 1
                    )
                    .onChange(of: store.state.configuration.refreshIntervalMinutes) { _, _ in store.save() }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var trackedModelsSection: some View {
        SettingsCard(title: "Tracked Model Prices", systemImage: "tag") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search the current OpenRouter model catalog or enter an exact provider/model ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Search models or paste provider/model-id", text: $trackedModelID)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTrackedModel)

                    Button("Add", systemImage: "plus", action: addTrackedModel)
                        .buttonStyle(.borderedProminent)
                        .disabled(trackedModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        Task { await store.refreshModelPricing() }
                    } label: {
                        Label(store.isRefreshingModelPrices ? "Refreshing" : "Refresh Prices", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isRefreshingModelPrices || store.state.configuration.trackedModelIDs.isEmpty)
                }

                if !modelSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(modelSuggestions) { model in
                            Button {
                                trackedModelID = model.id
                                addTrackedModel()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "cube.transparent")
                                        .foregroundStyle(Brand.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.name)
                                            .font(.callout.weight(.semibold))
                                        Text(model.id)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Add")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Brand.accent)
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if model.id != modelSuggestions.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Brand.panelStroke, lineWidth: 1)
                    )
                }

                if store.state.configuration.trackedModelIDs.isEmpty {
                    Text("No models tracked yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.state.configuration.trackedModelIDs, id: \.self) { modelID in
                            TrackedModelIDRow(modelID: modelID) {
                                store.removeTrackedModelID(modelID)
                            }
                        }
                    }
                }

                if let error = store.state.configuration.modelPricingError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Brand.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var budgetSection: some View {
        SettingsCard(title: "Budgets", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            VStack(alignment: .leading, spacing: 12) {
                budgetField("Low balance", value: $store.state.budget.lowBalanceThreshold)
                budgetField("Critical balance", value: $store.state.budget.criticalBalanceThreshold)
                budgetField("Daily budget", value: $store.state.budget.dailyBudget)
                budgetField("Monthly budget", value: $store.state.budget.monthlyBudget)

                if let budgetValidationMessage {
                    Label(budgetValidationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Brand.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onChange(of: store.state.budget) { _, _ in store.save() }
        }
        .frame(maxWidth: .infinity)
    }

    private var currencySection: some View {
        SettingsCard(title: "Currency", systemImage: "dollarsign.circle") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Display") {
                    Picker("Display currency", selection: $store.state.configuration.selectedCurrencyRawValue) {
                        ForEach(DisplayCurrency.allCases, id: \.rawValue) { currency in
                            Text(currency.code).tag(currency.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                    .onChange(of: store.state.configuration.selectedCurrencyRawValue) { _, _ in store.save() }
                }

                LabeledContent("USD → GBP") {
                    TextField(
                        "Exchange rate",
                        value: $store.state.configuration.usdToGBPRate,
                        format: .number.precision(.fractionLength(2...4))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disabled(store.state.configuration.selectedCurrency != .gbp)
                    .onChange(of: store.state.configuration.usdToGBPRate) { _, _ in store.save() }
                }

                Text("GBP remains display-only and uses the manual rate above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var notificationsSection: some View {
        SettingsCard(title: "Notifications", systemImage: "bell.badge") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Low balance", isOn: $store.state.configuration.lowBalanceAlertEnabled)
                        Toggle("Critical balance", isOn: $store.state.configuration.criticalBalanceAlertEnabled)
                        Toggle("Daily budget", isOn: $store.state.configuration.dailyBudgetAlertEnabled)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Monthly budget", isOn: $store.state.configuration.monthlyBudgetAlertEnabled)
                        Toggle("Refresh failures", isOn: $store.state.configuration.failureNotificationsEnabled)
                    }
                }
                .onChange(of: store.state.configuration.lowBalanceAlertEnabled) { _, _ in store.save() }
                .onChange(of: store.state.configuration.criticalBalanceAlertEnabled) { _, _ in store.save() }
                .onChange(of: store.state.configuration.dailyBudgetAlertEnabled) { _, _ in store.save() }
                .onChange(of: store.state.configuration.monthlyBudgetAlertEnabled) { _, _ in store.save() }
                .onChange(of: store.state.configuration.failureNotificationsEnabled) { _, _ in store.save() }

                Divider()

                HStack {
                    LabeledContent("System permission") {
                        Text(store.notificationAuthorizationText)
                            .font(.caption.weight(.semibold))
                    }

                    Spacer()

                    Button("Test Notification", systemImage: "bell") {
                        Task {
                            notificationTestMessage = await store.sendTestNotification()
                                ? "Test notification sent."
                                : "Notifications are not currently available."
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if let notificationTestMessage {
                    Text(notificationTestMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dataAndStatusSection: some View {
        SettingsCard(title: "Status & Data", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsStatusRow(label: "Connection", value: store.connectionState.label)
                SettingsStatusRow(label: "Stored key", value: store.state.profile.hasStoredKey ? "Yes" : "No")
                SettingsStatusRow(
                    label: "Analytics",
                    value: store.state.profile.isManagementKey ? "Account + activity" : "Key-level"
                )

                if let lastValidatedAt = store.state.profile.lastValidatedAt {
                    SettingsStatusRow(
                        label: "Last validated",
                        value: lastValidatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let error = store.state.configuration.lastRefreshError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Brand.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Export cached usage")
                            .font(.callout.weight(.semibold))
                        Text("Exports local settings and usage snapshots as JSON. API keys are never included.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Export JSON…", systemImage: "square.and.arrow.up") {
                        exportData()
                    }
                    .buttonStyle(.bordered)
                }

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modelSuggestions: [OpenRouterModel] {
        store.modelSuggestions(matching: trackedModelID)
    }

    private var budgetValidationMessage: String? {
        let budget = store.state.budget
        if budget.lowBalanceThreshold < 0 || budget.criticalBalanceThreshold < 0
            || budget.dailyBudget < 0 || budget.monthlyBudget < 0 {
            return "Budget values cannot be negative."
        }
        if budget.criticalBalanceThreshold > budget.lowBalanceThreshold {
            return "Critical balance must be lower than the low-balance threshold."
        }
        return nil
    }

    private var connectionStatusImage: String {
        switch store.connectionState {
        case .connected: return "checkmark.circle.fill"
        case .refreshing: return "arrow.triangle.2.circlepath"
        case .partial, .stale: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        case .setupNeeded: return "gearshape.fill"
        }
    }

    private var connectionStatusColor: Color {
        switch store.connectionState {
        case .connected: return Brand.accentSecondary
        case .refreshing: return Brand.accent
        case .partial, .stale: return Brand.warning
        case .offline: return Brand.danger
        case .setupNeeded: return .secondary
        }
    }

    private func budgetField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(store.state.configuration.selectedCurrency.code)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(
                    title,
                    value: value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 92)
                .accessibilityLabel(title)
            }
        }
    }

    private func addTrackedModel() {
        if store.addTrackedModelID(trackedModelID) {
            trackedModelID = ""
            Task { await store.refreshModelPricing() }
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.title = "Export OpenRouter Monitor Data"
        panel.nameFieldStringValue = "openrouter-monitor-export.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportState(to: url)
            exportMessage = "Exported to \(url.lastPathComponent)."
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .brandedPanel(cornerRadius: 16)
    }
}

private struct SettingsStatusRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }
}

private struct TrackedModelIDRow: View {
    let modelID: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(width: 24, height: 24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(modelID)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Remove model")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
    }
}

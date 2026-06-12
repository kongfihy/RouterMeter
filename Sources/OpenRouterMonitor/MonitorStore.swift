import Combine
import Foundation
import UserNotifications
import OpenRouterMonitorCore

struct AppConfiguration: Codable, Equatable {
    var selectedCurrencyRawValue = DisplayCurrency.usd.rawValue
    var usdToGBPRate = 0.79
    var menuBarModeRawValue = MenuBarDisplayMode.balanceRemaining.rawValue
    var refreshIntervalMinutes = 5.0
    var lastRefreshStatus = "Not connected"
    var lastRefreshError: String?
    var activeAlertRawValues: [String] = []
    var trackedModelIDs: [String] = []
    var modelPricingLastUpdatedAt: Date?
    var modelPricingError: String?

    var selectedCurrency: DisplayCurrency {
        get { DisplayCurrency(rawValue: selectedCurrencyRawValue) ?? .usd }
        set { selectedCurrencyRawValue = newValue.rawValue }
    }

    var menuBarMode: MenuBarDisplayMode {
        get { MenuBarDisplayMode(rawValue: menuBarModeRawValue) ?? .balanceRemaining }
        set { menuBarModeRawValue = newValue.rawValue }
    }

    var activeAlerts: Set<AlertKind> {
        get { Set(activeAlertRawValues.compactMap(AlertKind.init(rawValue:))) }
        set { activeAlertRawValues = newValue.map(\.rawValue).sorted() }
    }
}

struct ApiKeyProfile: Codable, Equatable {
    var label = "OpenRouter API Key"
    var isManagementKey = false
    var hasStoredKey = false
    var lastValidatedAt: Date?
}

struct CapturedGeneration: Codable, Equatable, Identifiable {
    var id: String { generationID }
    var generationID: String
    var capturedAt: Date
    var model: String
    var totalCost: Double
    var promptTokens: Int
    var completionTokens: Int
}

struct TrackedModelPricingRow: Equatable, Identifiable {
    let requestedID: String
    let model: OpenRouterModel?

    var id: String {
        requestedID.lowercased()
    }
}

struct PersistedMonitorState: Codable, Equatable {
    var configuration = AppConfiguration()
    var budget = BudgetSettings()
    var profile = ApiKeyProfile()
    var snapshots: [UsageSnapshot] = []
    var activityItems: [OpenRouterActivityItem] = []
    var apiKeys: [OpenRouterAPIKey] = []
    var trackedModels: [OpenRouterModel] = []
    var capturedGenerations: [CapturedGeneration] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try container.decodeIfPresent(AppConfiguration.self, forKey: .configuration) ?? AppConfiguration()
        budget = try container.decodeIfPresent(BudgetSettings.self, forKey: .budget) ?? BudgetSettings()
        profile = try container.decodeIfPresent(ApiKeyProfile.self, forKey: .profile) ?? ApiKeyProfile()
        snapshots = try container.decodeIfPresent([UsageSnapshot].self, forKey: .snapshots) ?? []
        activityItems = try container.decodeIfPresent([OpenRouterActivityItem].self, forKey: .activityItems) ?? []
        apiKeys = try container.decodeIfPresent([OpenRouterAPIKey].self, forKey: .apiKeys) ?? []
        trackedModels = try container.decodeIfPresent([OpenRouterModel].self, forKey: .trackedModels) ?? []
        capturedGenerations = try container.decodeIfPresent([CapturedGeneration].self, forKey: .capturedGenerations) ?? []
    }
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published var state: PersistedMonitorState
    @Published var isRefreshing = false
    @Published var isRefreshingModelPrices = false

    private let keychain = KeychainStore()
    private let client = OpenRouterClient()
    private var timer: Timer?
    private let stateURL: URL

    init() {
        stateURL = Self.defaultStateURL()
        state = Self.loadState(from: stateURL)
        refreshStoredKeyFlag()
    }

    var latestSnapshot: UsageSnapshot? {
        state.snapshots.sorted { $0.capturedAt > $1.capturedAt }.first
    }

    var moneyFormatter: MoneyFormatter {
        MoneyFormatter(
            currency: state.configuration.selectedCurrency,
            usdToGBP: state.configuration.usdToGBPRate
        )
    }

    var topModelSummaries: [ModelUsageSummary] {
        Array(ModelUsageSummary.aggregate(activityItems: state.activityItems).prefix(5))
    }

    var activityUsageSummary: ActivityUsageSummary? {
        ActivityUsageSummary.aggregate(activityItems: state.activityItems)
    }

    var burnDownSummary: CreditBurnDownSummary? {
        CreditBurnDownSummary.make(snapshot: latestSnapshot, activitySummary: activityUsageSummary)
    }

    var sortedAPIKeys: [OpenRouterAPIKey] {
        state.apiKeys.sorted {
            if $0.totalUsageMonthly == $1.totalUsageMonthly {
                return $0.totalUsageDaily > $1.totalUsageDaily
            }
            return $0.totalUsageMonthly > $1.totalUsageMonthly
        }
    }

    var trackedModelPricingRows: [TrackedModelPricingRow] {
        let modelsByKey = Dictionary(
            state.trackedModels.flatMap { model in
                [model.id, model.canonicalSlug ?? ""]
                    .map(Self.normalizedModelID)
                    .filter { !$0.isEmpty }
                    .map { ($0, model) }
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        return state.configuration.trackedModelIDs.map { modelID in
            TrackedModelPricingRow(
                requestedID: modelID,
                model: modelsByKey[Self.normalizedModelID(modelID)]
            )
        }
    }

    func startAutoRefresh() {
        timer?.invalidate()
        let interval = max(60, state.configuration.refreshIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func save() {
        do {
            let directory = stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: stateURL, options: [.atomic])
            startAutoRefresh()
        } catch {
            assertionFailure("State save failed: \(error)")
        }
    }

    func addTrackedModelID(_ modelID: String) -> Bool {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = Self.normalizedModelID(trimmed)
        guard !state.configuration.trackedModelIDs.contains(where: { Self.normalizedModelID($0) == normalized }) else {
            return false
        }
        state.configuration.trackedModelIDs.append(trimmed)
        state.configuration.modelPricingError = nil
        save()
        return true
    }

    func removeTrackedModelID(_ modelID: String) {
        let normalized = Self.normalizedModelID(modelID)
        state.configuration.trackedModelIDs.removeAll { Self.normalizedModelID($0) == normalized }
        state.trackedModels.removeAll { model in
            Self.normalizedModelID(model.id) == normalized || Self.normalizedModelID(model.canonicalSlug ?? "") == normalized
        }
        if state.configuration.trackedModelIDs.isEmpty {
            state.configuration.modelPricingError = nil
            state.configuration.modelPricingLastUpdatedAt = nil
        }
        save()
    }

    func refreshModelPricingIfNeeded() async {
        guard !state.configuration.trackedModelIDs.isEmpty else { return }
        if let lastUpdated = state.configuration.modelPricingLastUpdatedAt,
           Date().timeIntervalSince(lastUpdated) < 3_600,
           !state.trackedModels.isEmpty {
            return
        }
        await refreshModelPricing()
    }

    func refreshModelPricing() async {
        guard !isRefreshingModelPrices else { return }
        guard !state.configuration.trackedModelIDs.isEmpty else {
            state.trackedModels = []
            state.configuration.modelPricingError = nil
            state.configuration.modelPricingLastUpdatedAt = nil
            save()
            return
        }

        isRefreshingModelPrices = true
        defer { isRefreshingModelPrices = false }

        do {
            let models = try await client.fetchModels()
            let modelsByKey = Dictionary(
                models.flatMap { model in
                    [model.id, model.canonicalSlug ?? ""]
                        .map(Self.normalizedModelID)
                        .filter { !$0.isEmpty }
                        .map { ($0, model) }
                },
                uniquingKeysWith: { existing, _ in existing }
            )

            let trackedIDs = state.configuration.trackedModelIDs
            state.trackedModels = trackedIDs.compactMap { modelsByKey[Self.normalizedModelID($0)] }
            let missingIDs = trackedIDs.filter { modelsByKey[Self.normalizedModelID($0)] == nil }
            state.configuration.modelPricingLastUpdatedAt = Date()
            state.configuration.modelPricingError = missingIDs.isEmpty ? nil : "No pricing found for: \(missingIDs.joined(separator: ", "))"
            save()
        } catch {
            state.configuration.modelPricingError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            save()
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let apiKey = try keychain.loadAPIKey() ?? ""
            let service = RefreshService(fetcher: client)
            let outcome = try await service.refresh(
                apiKey: apiKey,
                includeCredits: state.profile.isManagementKey,
                budgetSettings: state.budget,
                previouslyActiveAlerts: state.configuration.activeAlerts
            )

            state.snapshots.insert(outcome.snapshot, at: 0)
            state.snapshots = Array(state.snapshots.prefix(500))
            state.activityItems = outcome.activityItems
            state.apiKeys = outcome.apiKeys
            state.profile.label = outcome.snapshot.keyLabel
            state.profile.hasStoredKey = true
            state.profile.lastValidatedAt = Date()
            state.configuration.activeAlerts = outcome.alertDecision.activeAlerts
            state.configuration.lastRefreshStatus = outcome.optionalDataWarning == nil ? "Connected" : "Connected"
            state.configuration.lastRefreshError = outcome.optionalDataWarning
            save()

            for alert in outcome.alertDecision.newAlerts {
                await sendNotification(for: alert)
            }
        } catch {
            state.configuration.lastRefreshStatus = "Refresh failed"
            state.configuration.lastRefreshError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            save()
            await sendFailureNotification(message: state.configuration.lastRefreshError ?? "Refresh failed.")
        }
    }

    func saveAPIKey(_ apiKey: String) {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try keychain.deleteAPIKey()
                state.profile.hasStoredKey = false
            } else {
                try keychain.saveAPIKey(trimmed)
                state.profile.hasStoredKey = true
            }
            save()
        } catch {
            assertionFailure("Keychain save failed: \(error)")
        }
    }

    func storedAPIKeyPlaceholder() -> String {
        state.profile.hasStoredKey ? "Stored in Keychain" : "Paste OpenRouter API key"
    }

    private func refreshStoredKeyFlag() {
        state.profile.hasStoredKey = ((try? keychain.loadAPIKey()) ?? nil) != nil
    }

    private func sendNotification(for alert: AlertKind) async {
        guard let notificationCenter else { return }
        await requestNotificationAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "OpenRouter Monitor"
        content.body = alert.notificationBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "openrouter-monitor-\(alert.rawValue)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }

    private func sendFailureNotification(message: String) async {
        guard let notificationCenter else { return }
        await requestNotificationAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = "OpenRouter refresh failed"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "openrouter-monitor-refresh-failed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }

    private func requestNotificationAuthorizationIfNeeded() async {
        guard let notificationCenter else { return }
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
    }

    private static func defaultStateURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("OpenRouterMonitor", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    private static func normalizedModelID(_ modelID: String) -> String {
        modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func loadState(from url: URL) -> PersistedMonitorState {
        guard let data = try? Data(contentsOf: url) else {
            return PersistedMonitorState()
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedMonitorState.self, from: data)
        } catch {
            return PersistedMonitorState()
        }
    }

    private var notificationCenter: UNUserNotificationCenter? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }
}

private extension AlertKind {
    var notificationBody: String {
        switch self {
        case .lowBalance:
            return "OpenRouter balance is below the low balance threshold."
        case .criticalBalance:
            return "OpenRouter balance is critically low."
        case .dailyBudget:
            return "Daily OpenRouter budget has been exceeded."
        case .monthlyBudget:
            return "Monthly OpenRouter budget has been exceeded."
        }
    }
}

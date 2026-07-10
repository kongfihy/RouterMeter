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
    var lowBalanceAlertEnabledOverride: Bool?
    var criticalBalanceAlertEnabledOverride: Bool?
    var dailyBudgetAlertEnabledOverride: Bool?
    var monthlyBudgetAlertEnabledOverride: Bool?
    var failureNotificationsEnabledOverride: Bool?
    var lastFailureNotificationAt: Date?

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

    var lowBalanceAlertEnabled: Bool {
        get { lowBalanceAlertEnabledOverride ?? true }
        set { lowBalanceAlertEnabledOverride = newValue }
    }

    var criticalBalanceAlertEnabled: Bool {
        get { criticalBalanceAlertEnabledOverride ?? true }
        set { criticalBalanceAlertEnabledOverride = newValue }
    }

    var dailyBudgetAlertEnabled: Bool {
        get { dailyBudgetAlertEnabledOverride ?? true }
        set { dailyBudgetAlertEnabledOverride = newValue }
    }

    var monthlyBudgetAlertEnabled: Bool {
        get { monthlyBudgetAlertEnabledOverride ?? true }
        set { monthlyBudgetAlertEnabledOverride = newValue }
    }

    var failureNotificationsEnabled: Bool {
        get { failureNotificationsEnabledOverride ?? true }
        set { failureNotificationsEnabledOverride = newValue }
    }

    func isAlertEnabled(_ alert: AlertKind) -> Bool {
        switch alert {
        case .lowBalance: return lowBalanceAlertEnabled
        case .criticalBalance: return criticalBalanceAlertEnabled
        case .dailyBudget: return dailyBudgetAlertEnabled
        case .monthlyBudget: return monthlyBudgetAlertEnabled
        }
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

enum MonitorConnectionState: Equatable {
    case setupNeeded
    case refreshing
    case connected
    case partial
    case stale
    case offline

    var label: String {
        switch self {
        case .setupNeeded: return "Setup needed"
        case .refreshing: return "Refreshing"
        case .connected: return "Connected"
        case .partial: return "Partial data"
        case .stale: return "Stale"
        case .offline: return "Offline"
        }
    }
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published var state: PersistedMonitorState
    @Published var isRefreshing = false
    @Published var isRefreshingModelPrices = false
    @Published var isValidatingAPIKey = false
    @Published var apiKeyValidationMessage: String?
    @Published var apiKeyValidationSucceeded = false
    @Published private(set) var modelCatalog: [OpenRouterModel] = []
    @Published private(set) var notificationAuthorizationText = "Checking…"
    @Published private(set) var notificationAuthorizationGranted = false

    private let keychain = KeychainStore()
    private let client = OpenRouterClient()
    private var timer: Timer?
    private let stateURL: URL
    private var hasStarted = false

    init() {
        stateURL = Self.defaultStateURL()
        state = Self.loadState(from: stateURL)
        refreshStoredKeyFlag()
    }

    var latestSnapshot: UsageSnapshot? {
        state.snapshots.sorted { $0.capturedAt > $1.capturedAt }.first
    }

    var connectionState: MonitorConnectionState {
        if isRefreshing {
            return .refreshing
        }
        if !state.profile.hasStoredKey {
            return .setupNeeded
        }
        if state.configuration.lastRefreshStatus == "Refresh failed" {
            return .offline
        }
        guard let latestSnapshot else {
            return .stale
        }
        let staleAfter = max(state.configuration.refreshIntervalMinutes * 120, 900)
        if Date().timeIntervalSince(latestSnapshot.capturedAt) > staleAfter {
            return .stale
        }
        if state.configuration.lastRefreshError != nil || state.configuration.lastRefreshStatus == "Partial data" {
            return .partial
        }
        return .connected
    }

    var hasActiveAlerts: Bool {
        !state.configuration.activeAlerts.isEmpty
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

    func modelSuggestions(matching query: String, limit: Int = 6) -> [OpenRouterModel] {
        let normalized = Self.normalizedModelID(query)
        guard !normalized.isEmpty else { return [] }
        return Array(
            modelCatalog
                .filter { model in
                    Self.normalizedModelID(model.id).contains(normalized)
                        || model.name.lowercased().contains(normalized)
                }
                .sorted { lhs, rhs in
                    let lhsStarts = Self.normalizedModelID(lhs.id).hasPrefix(normalized)
                    let rhsStarts = Self.normalizedModelID(rhs.id).hasPrefix(normalized)
                    if lhsStarts != rhsStarts { return lhsStarts }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                .prefix(limit)
        )
    }

    func start() async {
        startAutoRefresh()
        guard !hasStarted else { return }
        hasStarted = true

        if state.profile.hasStoredKey {
            await refresh()
        }
        await refreshModelPricingIfNeeded()
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

    func refreshModelCatalogIfNeeded() async {
        guard modelCatalog.isEmpty, !isRefreshingModelPrices else { return }
        isRefreshingModelPrices = true
        defer { isRefreshingModelPrices = false }

        do {
            modelCatalog = try await client.fetchModels()
        } catch {
            state.configuration.modelPricingError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
            modelCatalog = models
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
            state.configuration.activeAlerts = Set(
                outcome.alertDecision.activeAlerts.filter {
                    state.configuration.isAlertEnabled($0)
                }
            )
            state.configuration.lastRefreshStatus = outcome.optionalDataWarning == nil ? "Connected" : "Partial data"
            state.configuration.lastRefreshError = outcome.optionalDataWarning
            state.configuration.lastFailureNotificationAt = nil
            save()

            for alert in outcome.alertDecision.newAlerts where state.configuration.isAlertEnabled(alert) {
                await sendNotification(for: alert)
            }
        } catch {
            state.configuration.lastRefreshStatus = "Refresh failed"
            state.configuration.lastRefreshError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let shouldNotify = state.configuration.failureNotificationsEnabled
                && shouldSendFailureNotification
            if shouldNotify {
                state.configuration.lastFailureNotificationAt = Date()
            }
            save()
            if shouldNotify {
                await sendFailureNotification(message: state.configuration.lastRefreshError ?? "Refresh failed.")
            }
        }
    }

    @discardableResult
    func validateAndSaveAPIKey(_ apiKey: String) async -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            apiKeyValidationSucceeded = false
            apiKeyValidationMessage = "Enter a key before validating."
            return false
        }

        guard !isValidatingAPIKey else { return false }
        isValidatingAPIKey = true
        apiKeyValidationMessage = nil
        defer { isValidatingAPIKey = false }

        do {
            let keyResponse = try await client.fetchKey(apiKey: trimmed)
            var isManagementKey = false
            do {
                _ = try await client.fetchCredits(apiKey: trimmed)
                isManagementKey = true
            } catch OpenRouterClientError.forbidden {
                isManagementKey = false
            } catch {
                isManagementKey = false
            }

            try keychain.saveAPIKey(trimmed)
            state.profile.label = keyResponse.data.label
            state.profile.hasStoredKey = true
            state.profile.isManagementKey = isManagementKey
            state.profile.lastValidatedAt = Date()
            apiKeyValidationSucceeded = true
            apiKeyValidationMessage = isManagementKey
                ? "Key validated with account analytics access."
                : "Key validated with key-level usage access."
            save()
            await refresh()
            return true
        } catch {
            apiKeyValidationSucceeded = false
            apiKeyValidationMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func removeAPIKey() {
        do {
            try keychain.deleteAPIKey()
            state.profile = ApiKeyProfile()
            state.configuration.lastRefreshStatus = "Not connected"
            state.configuration.lastRefreshError = nil
            state.configuration.activeAlerts = []
            apiKeyValidationSucceeded = false
            apiKeyValidationMessage = "Key removed from Apple Keychain."
            save()
        } catch {
            apiKeyValidationSucceeded = false
            apiKeyValidationMessage = "Could not remove the key: \(error.localizedDescription)"
        }
    }

    func storedAPIKeyPlaceholder() -> String {
        state.profile.hasStoredKey ? "Stored in Keychain" : "Paste OpenRouter API key"
    }

    func exportState(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: url, options: [.atomic])
    }

    func refreshNotificationAuthorizationStatus() async {
        guard let notificationCenter else {
            notificationAuthorizationText = "Available in the packaged app"
            notificationAuthorizationGranted = false
            return
        }

        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationAuthorizationText = "Allowed"
            notificationAuthorizationGranted = true
        case .denied:
            notificationAuthorizationText = "Not allowed in System Settings"
            notificationAuthorizationGranted = false
        case .notDetermined:
            notificationAuthorizationText = "Not requested"
            notificationAuthorizationGranted = false
        @unknown default:
            notificationAuthorizationText = "Unknown"
            notificationAuthorizationGranted = false
        }
    }

    @discardableResult
    func sendTestNotification() async -> Bool {
        guard let notificationCenter else {
            await refreshNotificationAuthorizationStatus()
            return false
        }
        await requestNotificationAuthorizationIfNeeded()
        await refreshNotificationAuthorizationStatus()
        guard notificationAuthorizationGranted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "OpenRouter Monitor"
        content.body = "Notifications are ready."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "openrouter-monitor-test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            return false
        }
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

    private var shouldSendFailureNotification: Bool {
        guard let lastSent = state.configuration.lastFailureNotificationAt else { return true }
        return Date().timeIntervalSince(lastSent) > 1_800
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

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
    var spendPaceNotificationsEnabledOverride: Bool?
    var modelChangeNotificationsEnabledOverride: Bool?
    var keyHealthNotificationsEnabledOverride: Bool?
    var keyExpiryWarningDaysOverride: Int?
    var activeKeyHealthIssueIDsOverride: [String]?
    var spendPaceAlertActiveOverride: Bool?
    var lastFailureNotificationAt: Date?
    var generationLogsEnabledOverride: Bool?
    var generationLogLookbackHoursOverride: Int?
    var generationLogLimitOverride: Int?
    var lastGenerationLogRefreshAt: Date?
    var lastGenerationLogError: String?
    var lastLocalDayUsageError: String?

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

    var spendPaceNotificationsEnabled: Bool {
        get { spendPaceNotificationsEnabledOverride ?? true }
        set { spendPaceNotificationsEnabledOverride = newValue }
    }

    var modelChangeNotificationsEnabled: Bool {
        get { modelChangeNotificationsEnabledOverride ?? true }
        set { modelChangeNotificationsEnabledOverride = newValue }
    }

    var keyHealthNotificationsEnabled: Bool {
        get { keyHealthNotificationsEnabledOverride ?? true }
        set { keyHealthNotificationsEnabledOverride = newValue }
    }

    var keyExpiryWarningDays: Int {
        get { keyExpiryWarningDaysOverride ?? 14 }
        set { keyExpiryWarningDaysOverride = min(90, max(1, newValue)) }
    }

    var activeKeyHealthIssueIDs: Set<String> {
        get { Set(activeKeyHealthIssueIDsOverride ?? []) }
        set { activeKeyHealthIssueIDsOverride = newValue.sorted() }
    }

    var generationLogsEnabled: Bool {
        get { generationLogsEnabledOverride ?? true }
        set { generationLogsEnabledOverride = newValue }
    }

    var generationLogLookbackHours: Int {
        get { generationLogLookbackHoursOverride ?? 24 }
        set { generationLogLookbackHoursOverride = min(168, max(1, newValue)) }
    }

    var generationLogLimit: Int {
        get { generationLogLimitOverride ?? 100 }
        set { generationLogLimitOverride = min(500, max(10, newValue)) }
    }

    var spendPaceAlertActive: Bool {
        get { spendPaceAlertActiveOverride ?? false }
        set { spendPaceAlertActiveOverride = newValue }
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
    var occurredAt: Date?
    var model: String
    var providerName: String?
    var totalCost: Double
    var promptTokens: Int
    var completionTokens: Int
    var reasoningTokens: Int?
    var latencySeconds: Double?
    var generationTimeSeconds: Double?
    var finishReason: String?
    var cancelled: Bool?
    var streamed: Bool?
    var isBYOK: Bool?

    var displayDate: Date { occurredAt ?? capturedAt }
    var totalTokens: Int { promptTokens + completionTokens + (reasoningTokens ?? 0) }

    var statusLabel: String {
        if cancelled == true { return "Cancelled" }
        if let finishReason, !finishReason.isEmpty { return finishReason }
        return "Completed"
    }
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
    var localDayUsage: AnalyticsUsageSummary?
    var trackedModels: [OpenRouterModel] = []
    var capturedGenerations: [CapturedGeneration] = []
    var modelCatalogChanges: [ModelCatalogChange] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try container.decodeIfPresent(AppConfiguration.self, forKey: .configuration) ?? AppConfiguration()
        budget = try container.decodeIfPresent(BudgetSettings.self, forKey: .budget) ?? BudgetSettings()
        profile = try container.decodeIfPresent(ApiKeyProfile.self, forKey: .profile) ?? ApiKeyProfile()
        snapshots = try container.decodeIfPresent([UsageSnapshot].self, forKey: .snapshots) ?? []
        activityItems = try container.decodeIfPresent([OpenRouterActivityItem].self, forKey: .activityItems) ?? []
        apiKeys = try container.decodeIfPresent([OpenRouterAPIKey].self, forKey: .apiKeys) ?? []
        localDayUsage = try container.decodeIfPresent(AnalyticsUsageSummary.self, forKey: .localDayUsage)
        trackedModels = try container.decodeIfPresent([OpenRouterModel].self, forKey: .trackedModels) ?? []
        capturedGenerations = try container.decodeIfPresent([CapturedGeneration].self, forKey: .capturedGenerations) ?? []
        modelCatalogChanges = try container.decodeIfPresent([ModelCatalogChange].self, forKey: .modelCatalogChanges) ?? []
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
    static let shared = MonitorStore()

    @Published var state: PersistedMonitorState
    @Published var isRefreshing = false
    @Published var isRefreshingModelPrices = false
    @Published var isRefreshingGenerationLogs = false
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

    var currentLocalDayUsage: AnalyticsUsageSummary? {
        guard let summary = state.localDayUsage,
              Calendar.current.isDate(summary.periodStart, inSameDayAs: Date()) else { return nil }
        return summary
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

    var spendForecastSummary: SpendForecastSummary? {
        SpendForecastSummary.make(
            snapshot: latestSnapshot,
            activitySummary: activityUsageSummary,
            monthlyBudget: state.budget.monthlyBudget
        )
    }

    var keyHealthSummary: KeyHealthSummary {
        KeyHealthSummary.make(
            snapshot: latestSnapshot,
            apiKeys: state.apiKeys,
            expiryWarningDays: state.configuration.keyExpiryWarningDays
        )
    }

    var recentModelCatalogChanges: [ModelCatalogChange] {
        state.modelCatalogChanges.sorted { $0.detectedAt > $1.detectedAt }
    }

    var sortedCapturedGenerations: [CapturedGeneration] {
        state.capturedGenerations.sorted { $0.displayDate > $1.displayDate }
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
        guard !hasStarted else { return }
        hasStarted = true

        if ProcessInfo.processInfo.environment["ROUTERMETER_DISABLE_NETWORK"] == "1" {
            return
        }

        startAutoRefresh()

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

    func clearModelChangeHistory() {
        state.modelCatalogChanges = []
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
            let trackedIDs = state.configuration.trackedModelIDs
            let changes = ModelCatalogChangeDetector.detect(
                previous: state.trackedModels,
                current: models,
                trackedModelIDs: trackedIDs
            )
            let modelsByKey = Dictionary(
                models.flatMap { model in
                    [model.id, model.canonicalSlug ?? ""]
                        .map(Self.normalizedModelID)
                        .filter { !$0.isEmpty }
                        .map { ($0, model) }
                },
                uniquingKeysWith: { existing, _ in existing }
            )

            state.trackedModels = trackedIDs.compactMap { modelsByKey[Self.normalizedModelID($0)] }
            if !changes.isEmpty {
                state.modelCatalogChanges.insert(contentsOf: changes, at: 0)
                state.modelCatalogChanges = Array(state.modelCatalogChanges.prefix(100))
            }
            let missingIDs = trackedIDs.filter { modelsByKey[Self.normalizedModelID($0)] == nil }
            state.configuration.modelPricingLastUpdatedAt = Date()
            state.configuration.modelPricingError = missingIDs.isEmpty ? nil : "No pricing found for: \(missingIDs.joined(separator: ", "))"
            save()
            if state.configuration.modelChangeNotificationsEnabled, !changes.isEmpty {
                await sendModelChangeNotification(changes)
            }
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

            if state.profile.isManagementKey {
                let now = Date()
                let startOfLocalDay = Calendar.current.startOfDay(for: now)
                do {
                    state.localDayUsage = try await client.fetchUsageSummary(
                        apiKey: apiKey,
                        start: startOfLocalDay,
                        end: now
                    )
                    state.configuration.lastLocalDayUsageError = nil
                } catch {
                    state.configuration.lastLocalDayUsageError = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                }
            } else {
                state.localDayUsage = nil
                state.configuration.lastLocalDayUsageError = nil
            }

            let keyHealth = KeyHealthSummary.make(
                snapshot: outcome.snapshot,
                apiKeys: outcome.apiKeys,
                expiryWarningDays: state.configuration.keyExpiryWarningDays
            )
            let previousKeyIssueIDs = state.configuration.activeKeyHealthIssueIDs
            let currentKeyIssueIDs = Set(keyHealth.issues.map(\.id))
            let newKeyIssues = keyHealth.issues.filter { !previousKeyIssueIDs.contains($0.id) }
            state.configuration.activeKeyHealthIssueIDs = currentKeyIssueIDs

            let forecast = SpendForecastSummary.make(
                snapshot: outcome.snapshot,
                activitySummary: ActivityUsageSummary.aggregate(activityItems: outcome.activityItems),
                monthlyBudget: state.budget.monthlyBudget
            )
            let shouldSendSpendPaceAlert = forecast?.isSpendSpike == true
                && !state.configuration.spendPaceAlertActive
                && state.configuration.spendPaceNotificationsEnabled
            state.configuration.spendPaceAlertActive = forecast?.isSpendSpike ?? false
            save()

            for alert in outcome.alertDecision.newAlerts where state.configuration.isAlertEnabled(alert) {
                await sendNotification(for: alert)
            }
            if state.configuration.keyHealthNotificationsEnabled, !newKeyIssues.isEmpty {
                await sendKeyHealthNotification(newKeyIssues)
            }
            if shouldSendSpendPaceAlert, let forecast {
                await sendSpendPaceNotification(forecast)
            }
            if state.profile.isManagementKey, state.configuration.generationLogsEnabled {
                await refreshGenerationLogs(force: false)
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

    func clearGenerationLogs() {
        state.capturedGenerations = []
        state.configuration.lastGenerationLogRefreshAt = nil
        state.configuration.lastGenerationLogError = nil
        save()
    }

    func refreshGenerationLogs(force: Bool = true) async {
        guard state.profile.isManagementKey else {
            state.configuration.lastGenerationLogError = "A Management API key is required for detailed logs."
            save()
            return
        }
        guard state.configuration.generationLogsEnabled else { return }
        if !force, let lastRefresh = state.configuration.lastGenerationLogRefreshAt {
            let minimumInterval = max(state.configuration.refreshIntervalMinutes * 60, 900)
            guard Date().timeIntervalSince(lastRefresh) >= minimumInterval else { return }
        }
        guard !isRefreshingGenerationLogs else { return }

        isRefreshingGenerationLogs = true
        defer { isRefreshingGenerationLogs = false }

        do {
            let apiKey = try keychain.loadAPIKey() ?? ""
            let since = Calendar.current.date(
                byAdding: .hour,
                value: -state.configuration.generationLogLookbackHours,
                to: Date()
            ) ?? Date().addingTimeInterval(-86_400)
            let summaries = try await client.fetchRecentGenerationLogs(
                apiKey: apiKey,
                since: since,
                limit: state.configuration.generationLogLimit
            )
            let existingByID = Dictionary(
                uniqueKeysWithValues: state.capturedGenerations.map { ($0.generationID, $0) }
            )
            let capturedAt = Date()
            let merged = summaries.map { summary in
                let existing = existingByID[summary.generationID]
                return CapturedGeneration(
                    generationID: summary.generationID,
                    capturedAt: existing?.capturedAt ?? capturedAt,
                    occurredAt: summary.occurredAt ?? existing?.occurredAt,
                    model: summary.model == "Unknown model" ? (existing?.model ?? summary.model) : summary.model,
                    providerName: existing?.providerName,
                    totalCost: summary.totalCost > 0 ? summary.totalCost : (existing?.totalCost ?? 0),
                    promptTokens: summary.promptTokens > 0 ? summary.promptTokens : (existing?.promptTokens ?? 0),
                    completionTokens: summary.completionTokens > 0 ? summary.completionTokens : (existing?.completionTokens ?? 0),
                    reasoningTokens: summary.reasoningTokens > 0 ? summary.reasoningTokens : existing?.reasoningTokens,
                    latencySeconds: existing?.latencySeconds,
                    generationTimeSeconds: existing?.generationTimeSeconds,
                    finishReason: existing?.finishReason,
                    cancelled: existing?.cancelled,
                    streamed: existing?.streamed,
                    isBYOK: existing?.isBYOK
                )
            }

            let mergedIDs = Set(merged.map(\.generationID))
            let retained = state.capturedGenerations.filter { !mergedIDs.contains($0.generationID) }
            state.capturedGenerations = Array(
                (merged + retained)
                    .sorted { $0.displayDate > $1.displayDate }
                    .prefix(500)
            )

            // Hydrate only rows returned by this refresh that are new or still
            // incomplete. Once cached, older details are not requested again.
            let detailIDs = summaries.compactMap { summary -> String? in
                guard let existing = existingByID[summary.generationID] else {
                    return summary.generationID
                }
                return existing.model == "Unknown model" || existing.providerName == nil
                    ? summary.generationID
                    : nil
            }
            let details = await client.fetchGenerations(
                apiKey: apiKey,
                ids: detailIDs,
                maximumConcurrentRequests: 8
            )
            for detail in details {
                mergeGenerationDetail(detail)
            }

            state.configuration.lastGenerationLogRefreshAt = capturedAt
            state.configuration.lastGenerationLogError = nil
            save()
        } catch {
            state.configuration.lastGenerationLogError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            save()
        }
    }

    func loadGenerationDetails(id: String) async {
        guard state.profile.isManagementKey else { return }
        guard let index = state.capturedGenerations.firstIndex(where: { $0.generationID == id }) else { return }

        do {
            let apiKey = try keychain.loadAPIKey() ?? ""
            let generation = try await client.fetchGeneration(apiKey: apiKey, id: id)
            mergeGenerationDetail(generation, preferredIndex: index)
            save()
        } catch {
            state.configuration.lastGenerationLogError = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            save()
        }
    }

    private func mergeGenerationDetail(
        _ generation: OpenRouterGeneration,
        preferredIndex: Int? = nil
    ) {
        guard let index = preferredIndex
            ?? state.capturedGenerations.firstIndex(where: { $0.generationID == generation.id }) else { return }
        var item = state.capturedGenerations[index]
        item.occurredAt = generation.parsedCreatedAt ?? item.occurredAt
        item.model = generation.model ?? item.model
        item.providerName = generation.providerName ?? item.providerName
        item.totalCost = generation.totalCost ?? generation.usage ?? item.totalCost
        item.promptTokens = generation.tokensPrompt ?? item.promptTokens
        item.completionTokens = generation.tokensCompletion ?? item.completionTokens
        item.reasoningTokens = generation.nativeTokensReasoning ?? item.reasoningTokens
        item.latencySeconds = generation.latency.map { $0 / 1_000 }
        item.generationTimeSeconds = generation.generationTime.map { $0 / 1_000 }
        item.finishReason = generation.finishReason ?? generation.nativeFinishReason
        item.cancelled = generation.cancelled
        item.streamed = generation.streamed
        item.isBYOK = generation.isBYOK
        state.capturedGenerations[index] = item
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
            state.configuration.activeKeyHealthIssueIDs = []
            state.configuration.spendPaceAlertActive = false
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
        content.title = "RouterMeter"
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
        content.title = "RouterMeter"
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

    private func sendSpendPaceNotification(_ forecast: SpendForecastSummary) async {
        let pace = Int(((forecast.paceChangeRatio ?? 0) * 100).rounded())
        await sendIntelligenceNotification(
            title: "OpenRouter spend increased",
            body: "Recent spend is \(pace)% above the previous week. Projected month-end spend is \(moneyFormatter.string(fromUSDCredits: forecast.projectedMonthEndSpend)).",
            identifier: "spend-pace"
        )
    }

    private func sendKeyHealthNotification(_ issues: [KeyHealthIssue]) async {
        guard let issue = issues.first else { return }
        let additional = issues.count > 1 ? " Plus \(issues.count - 1) more key issue\(issues.count == 2 ? "" : "s")." : ""
        await sendIntelligenceNotification(
            title: "OpenRouter key needs attention",
            body: issue.notificationBody(formatter: moneyFormatter) + additional,
            identifier: "key-health"
        )
    }

    private func sendModelChangeNotification(_ changes: [ModelCatalogChange]) async {
        guard let change = changes.first else { return }
        let additional = changes.count > 1 ? " Plus \(changes.count - 1) more change\(changes.count == 2 ? "" : "s")." : ""
        await sendIntelligenceNotification(
            title: "Tracked model changed",
            body: change.notificationBody(formatter: moneyFormatter) + additional,
            identifier: "model-change"
        )
    }

    private func sendIntelligenceNotification(title: String, body: String, identifier: String) async {
        guard let notificationCenter else { return }
        await requestNotificationAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "openrouter-monitor-\(identifier)-\(Date().timeIntervalSince1970)",
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
        if let overridePath = ProcessInfo.processInfo.environment["ROUTERMETER_STATE_PATH"],
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("RouterMeter", isDirectory: true)
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

private extension KeyHealthIssue {
    func notificationBody(formatter: MoneyFormatter) -> String {
        switch kind {
        case .expired:
            return "\(keyName) has expired."
        case .expiringSoon:
            return "\(keyName) expires in \(max(0, daysRemaining ?? 0)) days."
        case .nearLimit:
            return "\(keyName) has \(formatter.string(fromUSDCredits: limitRemaining ?? 0)) remaining."
        }
    }
}

private extension ModelCatalogChange {
    func notificationBody(formatter: MoneyFormatter) -> String {
        switch kind {
        case .priceIncreased:
            return "\(modelName) pricing increased."
        case .priceDecreased:
            return "\(modelName) pricing decreased."
        case .pricingChanged:
            return "\(modelName) pricing changed."
        case .contextChanged:
            return "\(modelName) context changed to \((currentContextLength ?? 0).formatted())."
        case .expirationScheduled:
            return "\(modelName) is scheduled to expire \(expirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "soon")."
        case .unavailable:
            return "\(modelName) is no longer in the current model catalog."
        }
    }
}

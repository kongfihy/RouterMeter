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

struct PersistedMonitorState: Codable, Equatable {
    var configuration = AppConfiguration()
    var budget = BudgetSettings()
    var profile = ApiKeyProfile()
    var snapshots: [UsageSnapshot] = []
    var activityItems: [OpenRouterActivityItem] = []
    var capturedGenerations: [CapturedGeneration] = []
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published var state: PersistedMonitorState
    @Published var isRefreshing = false

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

import Foundation

public struct RefreshOutcome: Equatable, Sendable {
    public let snapshot: UsageSnapshot
    public let activityItems: [OpenRouterActivityItem]
    public let optionalDataWarning: String?
    public let alertDecision: AlertDecision

    public init(
        snapshot: UsageSnapshot,
        activityItems: [OpenRouterActivityItem],
        optionalDataWarning: String?,
        alertDecision: AlertDecision
    ) {
        self.snapshot = snapshot
        self.activityItems = activityItems
        self.optionalDataWarning = optionalDataWarning
        self.alertDecision = alertDecision
    }
}

public final class RefreshService<Fetcher: OpenRouterFetching>: @unchecked Sendable {
    private let fetcher: Fetcher
    private let alertEvaluator: AlertEvaluator

    public init(fetcher: Fetcher, alertEvaluator: AlertEvaluator = AlertEvaluator()) {
        self.fetcher = fetcher
        self.alertEvaluator = alertEvaluator
    }

    public func refresh(
        apiKey: String,
        includeCredits: Bool,
        budgetSettings: BudgetSettings,
        previouslyActiveAlerts: Set<AlertKind>
    ) async throws -> RefreshOutcome {
        let keyResponse = try await fetcher.fetchKey(apiKey: apiKey)
        var creditsResponse: OpenRouterCreditsResponse?
        var activityItems: [OpenRouterActivityItem] = []
        var warnings: [String] = []

        if includeCredits {
            do {
                creditsResponse = try await fetcher.fetchCredits(apiKey: apiKey)
            } catch {
                warnings.append("Account credits unavailable: \(Self.message(for: error))")
            }

            do {
                activityItems = try await fetcher.fetchActivity(apiKey: apiKey)
            } catch {
                warnings.append("Model activity unavailable: \(Self.message(for: error))")
            }
        }

        let snapshot = UsageSnapshot.make(keyResponse: keyResponse, creditsResponse: creditsResponse)
        let alertDecision = alertEvaluator.evaluate(
            snapshot: snapshot,
            settings: budgetSettings,
            previouslyActive: previouslyActiveAlerts
        )
        return RefreshOutcome(
            snapshot: snapshot,
            activityItems: activityItems,
            optionalDataWarning: warnings.isEmpty ? nil : warnings.joined(separator: " "),
            alertDecision: alertDecision
        )
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

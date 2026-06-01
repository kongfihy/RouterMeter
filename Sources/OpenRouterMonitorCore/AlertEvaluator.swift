import Foundation

public struct BudgetSettings: Codable, Equatable, Sendable {
    public var lowBalanceThreshold: Double
    public var criticalBalanceThreshold: Double
    public var dailyBudget: Double
    public var monthlyBudget: Double

    public init(
        lowBalanceThreshold: Double = 10,
        criticalBalanceThreshold: Double = 2,
        dailyBudget: Double = 2,
        monthlyBudget: Double = 50
    ) {
        self.lowBalanceThreshold = lowBalanceThreshold
        self.criticalBalanceThreshold = criticalBalanceThreshold
        self.dailyBudget = dailyBudget
        self.monthlyBudget = monthlyBudget
    }
}

public enum AlertKind: String, CaseIterable, Codable, Hashable, Sendable {
    case lowBalance
    case criticalBalance
    case dailyBudget
    case monthlyBudget
}

public struct AlertDecision: Equatable, Sendable {
    public let newAlerts: [AlertKind]
    public let activeAlerts: Set<AlertKind>

    public init(newAlerts: [AlertKind], activeAlerts: Set<AlertKind>) {
        self.newAlerts = newAlerts
        self.activeAlerts = activeAlerts
    }
}

public struct AlertEvaluator: Sendable {
    public init() {}

    public func evaluate(
        snapshot: UsageSnapshot,
        settings: BudgetSettings,
        previouslyActive: Set<AlertKind>
    ) -> AlertDecision {
        var currentlyActive = Set<AlertKind>()

        if let remaining = snapshot.accountRemainingCredits {
            if remaining < settings.criticalBalanceThreshold {
                currentlyActive.insert(.criticalBalance)
            } else if remaining < settings.lowBalanceThreshold {
                currentlyActive.insert(.lowBalance)
            }
        } else if let remaining = snapshot.keyLimitRemaining {
            if remaining < settings.criticalBalanceThreshold {
                currentlyActive.insert(.criticalBalance)
            } else if remaining < settings.lowBalanceThreshold {
                currentlyActive.insert(.lowBalance)
            }
        }

        if settings.dailyBudget > 0, snapshot.usageDaily > settings.dailyBudget {
            currentlyActive.insert(.dailyBudget)
        }

        if settings.monthlyBudget > 0, snapshot.usageMonthly > settings.monthlyBudget {
            currentlyActive.insert(.monthlyBudget)
        }

        let newAlerts = AlertKind.allCases.filter { currentlyActive.contains($0) && !previouslyActive.contains($0) }
        return AlertDecision(newAlerts: newAlerts, activeAlerts: currentlyActive)
    }
}

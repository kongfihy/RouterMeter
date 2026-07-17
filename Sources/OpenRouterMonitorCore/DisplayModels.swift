import Foundation

public enum MenuBarDisplayMode: String, CaseIterable, Codable, Sendable {
    case balanceRemaining
    case percentRemaining
    case todaySpend
    case todayAndBalance

    public var label: String {
        switch self {
        case .balanceRemaining:
            return "Balance"
        case .percentRemaining:
            return "Percent"
        case .todaySpend:
            return "Today"
        case .todayAndBalance:
            return "Today + Balance"
        }
    }
}

public enum DisplayCurrency: String, CaseIterable, Codable, Sendable {
    case usd
    case gbp

    public var code: String {
        rawValue.uppercased()
    }

    public var symbol: String {
        switch self {
        case .usd:
            return "$"
        case .gbp:
            return "£"
        }
    }
}

public struct MoneyFormatter: Sendable {
    public let currency: DisplayCurrency
    public let usdToGBP: Double

    public init(currency: DisplayCurrency, usdToGBP: Double) {
        self.currency = currency
        self.usdToGBP = usdToGBP
    }

    public func displayAmount(fromUSDCredits amount: Double) -> Double {
        switch currency {
        case .usd:
            return amount
        case .gbp:
            return amount * usdToGBP
        }
    }

    public func string(fromUSDCredits amount: Double) -> String {
        let converted = displayAmount(fromUSDCredits: amount)
        return "\(currency.symbol)\(converted.formatted(.number.precision(.fractionLength(2))))"
    }

    public func detailedUsageString(fromUSDCredits amount: Double) -> String {
        let converted = displayAmount(fromUSDCredits: amount)
        let absoluteAmount = abs(converted)
        let maximumFractionDigits: Int

        switch absoluteAmount {
        case 1...:
            maximumFractionDigits = 2
        case 0.01...:
            maximumFractionDigits = 4
        case 0.0001...:
            maximumFractionDigits = 6
        case 0 where converted == 0:
            maximumFractionDigits = 2
        default:
            maximumFractionDigits = 8
        }

        let value = converted.formatted(
            .number.precision(.fractionLength(2...maximumFractionDigits))
        )
        return "\(currency.symbol)\(value)"
    }
}

public struct MenuBarTitleBuilder: Sendable {
    public static func title(
        snapshot: UsageSnapshot?,
        mode: MenuBarDisplayMode,
        moneyFormatter: MoneyFormatter,
        todaySpendOverride: Double? = nil
    ) -> String {
        guard let snapshot else { return "OR -" }

        switch mode {
        case .balanceRemaining:
            if let remaining = snapshot.accountRemainingCredits {
                return "OR \(moneyFormatter.string(fromUSDCredits: remaining))"
            }
            if let keyRemaining = snapshot.keyLimitRemaining {
                return "OR \(moneyFormatter.string(fromUSDCredits: keyRemaining))"
            }
            return "OR \(moneyFormatter.string(fromUSDCredits: snapshot.usageAllTimeIncludingBYOK)) used"
        case .percentRemaining:
            if let percent = snapshot.accountPercentRemaining {
                return "OR \((percent * 100).formatted(.number.precision(.fractionLength(0))))%"
            }
            guard let limit = snapshot.keyLimit, limit > 0, let remaining = snapshot.keyLimitRemaining else {
                return "OR -%"
            }
            let percent = max(0, min(1, remaining / limit))
            return "OR \((percent * 100).formatted(.number.precision(.fractionLength(0))))%"
        case .todaySpend:
            let today = todaySpendOverride ?? snapshot.usageDailyIncludingBYOK
            return "OR \(moneyFormatter.string(fromUSDCredits: today)) today"
        case .todayAndBalance:
            let today = todaySpendOverride ?? snapshot.usageDailyIncludingBYOK
            let remaining = snapshot.accountRemainingCredits ?? snapshot.keyLimitRemaining
            guard let remaining else {
                return "OR \(moneyFormatter.string(fromUSDCredits: today)) today"
            }
            return "OR \(moneyFormatter.string(fromUSDCredits: today)) · \(moneyFormatter.string(fromUSDCredits: remaining))"
        }
    }
}

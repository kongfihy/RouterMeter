import Foundation

public enum MenuBarDisplayMode: String, CaseIterable, Codable, Sendable {
    case balanceRemaining
    case percentRemaining
    case todaySpend

    public var label: String {
        switch self {
        case .balanceRemaining:
            return "Balance"
        case .percentRemaining:
            return "Percent"
        case .todaySpend:
            return "Today"
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
}

public struct MenuBarTitleBuilder: Sendable {
    public static func title(
        snapshot: UsageSnapshot?,
        mode: MenuBarDisplayMode,
        moneyFormatter: MoneyFormatter
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
            return "OR \(moneyFormatter.string(fromUSDCredits: snapshot.usageAllTime)) used"
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
            return "OR \(moneyFormatter.string(fromUSDCredits: snapshot.usageDaily)) today"
        }
    }
}

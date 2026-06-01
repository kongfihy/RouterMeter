import Foundation

public struct OpenRouterKeyResponse: Codable, Equatable, Sendable {
    public let data: OpenRouterKeyData

    public init(data: OpenRouterKeyData) {
        self.data = data
    }
}

public struct OpenRouterKeyData: Codable, Equatable, Sendable {
    public let label: String
    public let limit: Double?
    public let limitReset: String?
    public let limitRemaining: Double?
    public let includeBYOKInLimit: Bool
    public let usage: Double
    public let usageDaily: Double
    public let usageWeekly: Double
    public let usageMonthly: Double
    public let byokUsage: Double
    public let byokUsageDaily: Double
    public let byokUsageWeekly: Double
    public let byokUsageMonthly: Double
    public let isFreeTier: Bool

    enum CodingKeys: String, CodingKey {
        case label
        case limit
        case limitReset = "limit_reset"
        case limitRemaining = "limit_remaining"
        case includeBYOKInLimit = "include_byok_in_limit"
        case usage
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case byokUsage = "byok_usage"
        case byokUsageDaily = "byok_usage_daily"
        case byokUsageWeekly = "byok_usage_weekly"
        case byokUsageMonthly = "byok_usage_monthly"
        case isFreeTier = "is_free_tier"
    }

    public init(
        label: String,
        limit: Double?,
        limitReset: String?,
        limitRemaining: Double?,
        includeBYOKInLimit: Bool,
        usage: Double,
        usageDaily: Double,
        usageWeekly: Double,
        usageMonthly: Double,
        byokUsage: Double,
        byokUsageDaily: Double,
        byokUsageWeekly: Double,
        byokUsageMonthly: Double,
        isFreeTier: Bool
    ) {
        self.label = label
        self.limit = limit
        self.limitReset = limitReset
        self.limitRemaining = limitRemaining
        self.includeBYOKInLimit = includeBYOKInLimit
        self.usage = usage
        self.usageDaily = usageDaily
        self.usageWeekly = usageWeekly
        self.usageMonthly = usageMonthly
        self.byokUsage = byokUsage
        self.byokUsageDaily = byokUsageDaily
        self.byokUsageWeekly = byokUsageWeekly
        self.byokUsageMonthly = byokUsageMonthly
        self.isFreeTier = isFreeTier
    }
}

public struct OpenRouterCreditsResponse: Codable, Equatable, Sendable {
    public let data: OpenRouterCreditsData

    public init(data: OpenRouterCreditsData) {
        self.data = data
    }
}

public struct OpenRouterCreditsData: Codable, Equatable, Sendable {
    public let totalCredits: Double
    public let totalUsage: Double

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }

    public init(totalCredits: Double, totalUsage: Double) {
        self.totalCredits = totalCredits
        self.totalUsage = totalUsage
    }
}

public struct OpenRouterActivityResponse: Codable, Equatable, Sendable {
    public let data: [OpenRouterActivityItem]

    public init(data: [OpenRouterActivityItem]) {
        self.data = data
    }
}

public struct OpenRouterActivityItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(date)-\(endpointID)-\(model)-\(providerName)"
    }

    public let byokUsageInference: Double
    public let completionTokens: Int
    public let date: String
    public let endpointID: String
    public let model: String
    public let modelPermaslug: String?
    public let promptTokens: Int
    public let providerName: String
    public let reasoningTokens: Int
    public let requests: Int
    public let usage: Double

    enum CodingKeys: String, CodingKey {
        case byokUsageInference = "byok_usage_inference"
        case completionTokens = "completion_tokens"
        case date
        case endpointID = "endpoint_id"
        case model
        case modelPermaslug = "model_permaslug"
        case promptTokens = "prompt_tokens"
        case providerName = "provider_name"
        case reasoningTokens = "reasoning_tokens"
        case requests
        case usage
    }

    public init(
        byokUsageInference: Double,
        completionTokens: Int,
        date: String,
        endpointID: String,
        model: String,
        modelPermaslug: String?,
        promptTokens: Int,
        providerName: String,
        reasoningTokens: Int,
        requests: Int,
        usage: Double
    ) {
        self.byokUsageInference = byokUsageInference
        self.completionTokens = completionTokens
        self.date = date
        self.endpointID = endpointID
        self.model = model
        self.modelPermaslug = modelPermaslug
        self.promptTokens = promptTokens
        self.providerName = providerName
        self.reasoningTokens = reasoningTokens
        self.requests = requests
        self.usage = usage
    }
}

public struct ModelUsageSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String { model }
    public let model: String
    public let providerName: String
    public let requests: Int
    public let usage: Double
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int

    public var totalTokens: Int {
        promptTokens + completionTokens + reasoningTokens
    }

    public init(
        model: String,
        providerName: String,
        requests: Int,
        usage: Double,
        promptTokens: Int,
        completionTokens: Int,
        reasoningTokens: Int
    ) {
        self.model = model
        self.providerName = providerName
        self.requests = requests
        self.usage = usage
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
    }

    public static func aggregate(activityItems: [OpenRouterActivityItem]) -> [ModelUsageSummary] {
        let grouped = Dictionary(grouping: activityItems, by: \.model)
        return grouped.map { model, items in
            let providerName = items.first?.providerName ?? ""
            return ModelUsageSummary(
                model: model,
                providerName: providerName,
                requests: items.reduce(0) { $0 + $1.requests },
                usage: items.reduce(0) { $0 + $1.usage },
                promptTokens: items.reduce(0) { $0 + $1.promptTokens },
                completionTokens: items.reduce(0) { $0 + $1.completionTokens },
                reasoningTokens: items.reduce(0) { $0 + $1.reasoningTokens }
            )
        }
        .sorted {
            if $0.usage == $1.usage {
                return $0.requests > $1.requests
            }
            return $0.usage > $1.usage
        }
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let keyLabel: String
    public let keyLimit: Double?
    public let keyLimitRemaining: Double?
    public let usageAllTime: Double
    public let usageDaily: Double
    public let usageWeekly: Double
    public let usageMonthly: Double
    public let byokUsageAllTime: Double
    public let byokUsageDaily: Double
    public let byokUsageWeekly: Double
    public let byokUsageMonthly: Double
    public let totalCredits: Double?
    public let accountTotalUsage: Double?

    public init(
        capturedAt: Date,
        keyLabel: String,
        keyLimit: Double?,
        keyLimitRemaining: Double?,
        usageAllTime: Double,
        usageDaily: Double,
        usageWeekly: Double,
        usageMonthly: Double,
        byokUsageAllTime: Double,
        byokUsageDaily: Double,
        byokUsageWeekly: Double,
        byokUsageMonthly: Double,
        totalCredits: Double?,
        accountTotalUsage: Double?
    ) {
        self.capturedAt = capturedAt
        self.keyLabel = keyLabel
        self.keyLimit = keyLimit
        self.keyLimitRemaining = keyLimitRemaining
        self.usageAllTime = usageAllTime
        self.usageDaily = usageDaily
        self.usageWeekly = usageWeekly
        self.usageMonthly = usageMonthly
        self.byokUsageAllTime = byokUsageAllTime
        self.byokUsageDaily = byokUsageDaily
        self.byokUsageWeekly = byokUsageWeekly
        self.byokUsageMonthly = byokUsageMonthly
        self.totalCredits = totalCredits
        self.accountTotalUsage = accountTotalUsage
    }

    public var accountRemainingCredits: Double? {
        guard let totalCredits, let accountTotalUsage else { return nil }
        return totalCredits - accountTotalUsage
    }

    public var accountPercentRemaining: Double? {
        guard let totalCredits, totalCredits > 0, let accountRemainingCredits else { return nil }
        return max(0, min(1, accountRemainingCredits / totalCredits))
    }

    public static func make(
        keyResponse: OpenRouterKeyResponse,
        creditsResponse: OpenRouterCreditsResponse?,
        capturedAt: Date = Date()
    ) -> UsageSnapshot {
        UsageSnapshot(
            capturedAt: capturedAt,
            keyLabel: keyResponse.data.label,
            keyLimit: keyResponse.data.limit,
            keyLimitRemaining: keyResponse.data.limitRemaining,
            usageAllTime: keyResponse.data.usage,
            usageDaily: keyResponse.data.usageDaily,
            usageWeekly: keyResponse.data.usageWeekly,
            usageMonthly: keyResponse.data.usageMonthly,
            byokUsageAllTime: keyResponse.data.byokUsage,
            byokUsageDaily: keyResponse.data.byokUsageDaily,
            byokUsageWeekly: keyResponse.data.byokUsageWeekly,
            byokUsageMonthly: keyResponse.data.byokUsageMonthly,
            totalCredits: creditsResponse?.data.totalCredits,
            accountTotalUsage: creditsResponse?.data.totalUsage
        )
    }
}

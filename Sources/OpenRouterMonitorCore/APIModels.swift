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

public struct OpenRouterAPIKeysResponse: Codable, Equatable, Sendable {
    public let data: [OpenRouterAPIKey]

    public init(data: [OpenRouterAPIKey]) {
        self.data = data
    }
}

public struct OpenRouterAPIKey: Codable, Equatable, Identifiable, Sendable {
    public var id: String { hash }

    public let hash: String
    public let name: String?
    public let label: String
    public let disabled: Bool
    public let limit: Double?
    public let limitRemaining: Double?
    public let limitReset: String?
    public let usage: Double
    public let usageDaily: Double
    public let usageWeekly: Double
    public let usageMonthly: Double
    public let byokUsage: Double
    public let byokUsageDaily: Double
    public let byokUsageWeekly: Double
    public let byokUsageMonthly: Double
    public let includeBYOKInLimit: Bool?
    public let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case hash
        case name
        case label
        case disabled
        case limit
        case limitRemaining = "limit_remaining"
        case limitReset = "limit_reset"
        case usage
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case byokUsage = "byok_usage"
        case byokUsageDaily = "byok_usage_daily"
        case byokUsageWeekly = "byok_usage_weekly"
        case byokUsageMonthly = "byok_usage_monthly"
        case includeBYOKInLimit = "include_byok_in_limit"
        case expiresAt = "expires_at"
    }

    public init(
        hash: String,
        name: String?,
        label: String,
        disabled: Bool,
        limit: Double?,
        limitRemaining: Double?,
        limitReset: String?,
        usage: Double,
        usageDaily: Double,
        usageWeekly: Double,
        usageMonthly: Double,
        byokUsage: Double,
        byokUsageDaily: Double,
        byokUsageWeekly: Double,
        byokUsageMonthly: Double,
        includeBYOKInLimit: Bool?,
        expiresAt: String?
    ) {
        self.hash = hash
        self.name = name
        self.label = label
        self.disabled = disabled
        self.limit = limit
        self.limitRemaining = limitRemaining
        self.limitReset = limitReset
        self.usage = usage
        self.usageDaily = usageDaily
        self.usageWeekly = usageWeekly
        self.usageMonthly = usageMonthly
        self.byokUsage = byokUsage
        self.byokUsageDaily = byokUsageDaily
        self.byokUsageWeekly = byokUsageWeekly
        self.byokUsageMonthly = byokUsageMonthly
        self.includeBYOKInLimit = includeBYOKInLimit
        self.expiresAt = expiresAt
    }
}

public struct OpenRouterModelsResponse: Codable, Equatable, Sendable {
    public let data: [OpenRouterModel]

    public init(data: [OpenRouterModel]) {
        self.data = data
    }
}

public struct OpenRouterModel: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let canonicalSlug: String?
    public let name: String
    public let description: String?
    public let contextLength: Int?
    public let pricing: OpenRouterModelPricing

    enum CodingKeys: String, CodingKey {
        case id
        case canonicalSlug = "canonical_slug"
        case name
        case description
        case contextLength = "context_length"
        case pricing
    }

    public init(
        id: String,
        canonicalSlug: String?,
        name: String,
        description: String?,
        contextLength: Int?,
        pricing: OpenRouterModelPricing
    ) {
        self.id = id
        self.canonicalSlug = canonicalSlug
        self.name = name
        self.description = description
        self.contextLength = contextLength
        self.pricing = pricing
    }
}

public struct OpenRouterModelPricing: Codable, Equatable, Sendable {
    public let prompt: String?
    public let completion: String?
    public let request: String?
    public let image: String?
    public let inputCacheRead: String?

    enum CodingKeys: String, CodingKey {
        case prompt
        case completion
        case request
        case image
        case inputCacheRead = "input_cache_read"
    }

    public init(
        prompt: String?,
        completion: String?,
        request: String?,
        image: String?,
        inputCacheRead: String?
    ) {
        self.prompt = prompt
        self.completion = completion
        self.request = request
        self.image = image
        self.inputCacheRead = inputCacheRead
    }

    public var promptPricePerMillion: Double? {
        pricePerMillion(prompt)
    }

    public var completionPricePerMillion: Double? {
        pricePerMillion(completion)
    }

    public var cacheReadPricePerMillion: Double? {
        pricePerMillion(inputCacheRead)
    }

    private func pricePerMillion(_ value: String?) -> Double? {
        guard let value, let price = Double(value) else { return nil }
        return price * 1_000_000
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
                usage: items.reduce(0) { $0 + $1.totalUsage },
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

public struct ActivityDaySummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        DateFormatter.openRouterActivityDay.string(from: date)
    }

    public let date: Date
    public let openRouterUsage: Double
    public let byokUsage: Double
    public let requests: Int
    public let totalTokens: Int

    public var totalUsage: Double {
        openRouterUsage + byokUsage
    }

    public init(
        date: Date,
        openRouterUsage: Double,
        byokUsage: Double,
        requests: Int,
        totalTokens: Int
    ) {
        self.date = date
        self.openRouterUsage = openRouterUsage
        self.byokUsage = byokUsage
        self.requests = requests
        self.totalTokens = totalTokens
    }
}

public struct ActivityUsageSummary: Codable, Equatable, Sendable {
    public let trend: [ActivityDaySummary]
    public let latestDate: Date?
    public let latestDayUsage: Double
    public let latestDayByokUsage: Double
    public let last7DaysUsage: Double
    public let last7DaysByokUsage: Double
    public let last7WindowDays: Int
    public let last30DaysUsage: Double
    public let last30DaysByokUsage: Double
    public let last30WindowDays: Int
    public let last30DaysRequests: Int
    public let last30DaysTokens: Int

    public var latestDayOpenRouterUsage: Double {
        latestDayUsage - latestDayByokUsage
    }

    public var last7DaysOpenRouterUsage: Double {
        last7DaysUsage - last7DaysByokUsage
    }

    public var last30DaysOpenRouterUsage: Double {
        last30DaysUsage - last30DaysByokUsage
    }

    public init(
        trend: [ActivityDaySummary],
        latestDate: Date?,
        latestDayUsage: Double,
        latestDayByokUsage: Double,
        last7DaysUsage: Double,
        last7DaysByokUsage: Double,
        last7WindowDays: Int,
        last30DaysUsage: Double,
        last30DaysByokUsage: Double,
        last30WindowDays: Int,
        last30DaysRequests: Int,
        last30DaysTokens: Int
    ) {
        self.trend = trend
        self.latestDate = latestDate
        self.latestDayUsage = latestDayUsage
        self.latestDayByokUsage = latestDayByokUsage
        self.last7DaysUsage = last7DaysUsage
        self.last7DaysByokUsage = last7DaysByokUsage
        self.last7WindowDays = last7WindowDays
        self.last30DaysUsage = last30DaysUsage
        self.last30DaysByokUsage = last30DaysByokUsage
        self.last30WindowDays = last30WindowDays
        self.last30DaysRequests = last30DaysRequests
        self.last30DaysTokens = last30DaysTokens
    }

    public static func aggregate(activityItems: [OpenRouterActivityItem]) -> ActivityUsageSummary? {
        let datedItems = activityItems.compactMap { item -> (Date, OpenRouterActivityItem)? in
            guard let date = item.activityDate else { return nil }
            return (date, item)
        }

        let groupedByDate = Dictionary(grouping: datedItems) { entry in
            entry.0
        }

        let trend: [ActivityDaySummary] = groupedByDate.map { date, entries in
            let openRouterUsage = entries.reduce(0) { partialResult, entry in
                partialResult + entry.1.usage
            }
            let byokUsage = entries.reduce(0) { partialResult, entry in
                partialResult + entry.1.byokUsageInference
            }
            let requests = entries.reduce(0) { partialResult, entry in
                partialResult + entry.1.requests
            }
            let totalTokens = entries.reduce(0) { partialResult, entry in
                partialResult + entry.1.totalTokens
            }

            return ActivityDaySummary(
                date: date,
                openRouterUsage: openRouterUsage,
                byokUsage: byokUsage,
                requests: requests,
                totalTokens: totalTokens
            )
        }
        .sorted { lhs, rhs in
            lhs.date < rhs.date
        }

        let trendDates = trend.map { $0.date }
        guard let latestDate = trendDates.max() else {
            return nil
        }

        let calendar = Calendar.utc
        let last7Start = calendar.date(byAdding: .day, value: -6, to: latestDate) ?? latestDate
        let last30Start = calendar.date(byAdding: .day, value: -29, to: latestDate) ?? latestDate

        let latestDayItems = trend.filter { calendar.isDate($0.date, inSameDayAs: latestDate) }
        let last7Items = trend.filter { $0.date >= last7Start && $0.date <= latestDate }
        let last30Items = trend.filter { $0.date >= last30Start && $0.date <= latestDate }

        let last7WindowDays = max(1, (calendar.dateComponents([.day], from: last7Start, to: latestDate).day ?? 0) + 1)
        let last30WindowDays = max(1, (calendar.dateComponents([.day], from: last30Start, to: latestDate).day ?? 0) + 1)

        let latestDayUsage = latestDayItems.reduce(0) { $0 + $1.totalUsage }
        let latestDayByokUsage = latestDayItems.reduce(0) { $0 + $1.byokUsage }
        let last7DaysUsage = last7Items.reduce(0) { $0 + $1.totalUsage }
        let last7DaysByokUsage = last7Items.reduce(0) { $0 + $1.byokUsage }
        let last30DaysUsage = last30Items.reduce(0) { $0 + $1.totalUsage }
        let last30DaysByokUsage = last30Items.reduce(0) { $0 + $1.byokUsage }
        let last30DaysRequests = last30Items.reduce(0) { $0 + $1.requests }
        let last30DaysTokens = last30Items.reduce(0) { $0 + $1.totalTokens }

        return ActivityUsageSummary(
            trend: trend,
            latestDate: latestDate,
            latestDayUsage: latestDayUsage,
            latestDayByokUsage: latestDayByokUsage,
            last7DaysUsage: last7DaysUsage,
            last7DaysByokUsage: last7DaysByokUsage,
            last7WindowDays: last7WindowDays,
            last30DaysUsage: last30DaysUsage,
            last30DaysByokUsage: last30DaysByokUsage,
            last30WindowDays: last30WindowDays,
            last30DaysRequests: last30DaysRequests,
            last30DaysTokens: last30DaysTokens
        )
    }
}

public struct CreditBurnDownSummary: Codable, Equatable, Sendable {
    public let remainingCredits: Double
    public let averageDailySpend: Double
    public let estimatedDaysRemaining: Double
    public let exhaustionDate: Date

    public init(
        remainingCredits: Double,
        averageDailySpend: Double,
        estimatedDaysRemaining: Double,
        exhaustionDate: Date
    ) {
        self.remainingCredits = remainingCredits
        self.averageDailySpend = averageDailySpend
        self.estimatedDaysRemaining = estimatedDaysRemaining
        self.exhaustionDate = exhaustionDate
    }

    public static func make(snapshot: UsageSnapshot?, activitySummary: ActivityUsageSummary?) -> CreditBurnDownSummary? {
        guard
            let remainingCredits = snapshot?.accountRemainingCredits,
            remainingCredits > 0,
            let activitySummary
        else {
            return nil
        }

        let average7Day = activitySummary.last7DaysUsage / Double(max(activitySummary.last7WindowDays, 1))
        let average30Day = activitySummary.last30DaysUsage / Double(max(activitySummary.last30WindowDays, 1))
        let averageDailySpend = average7Day > 0 ? average7Day : average30Day

        guard averageDailySpend > 0 else { return nil }

        let estimatedDaysRemaining = remainingCredits / averageDailySpend
        let exhaustionDate = Date().addingTimeInterval(estimatedDaysRemaining * 86_400)

        return CreditBurnDownSummary(
            remainingCredits: remainingCredits,
            averageDailySpend: averageDailySpend,
            estimatedDaysRemaining: estimatedDaysRemaining,
            exhaustionDate: exhaustionDate
        )
    }
}

public extension OpenRouterActivityItem {
    var totalUsage: Double {
        usage + byokUsageInference
    }

    var totalTokens: Int {
        promptTokens + completionTokens + reasoningTokens
    }

    var activityDate: Date? {
        let datePart = String(date.prefix(10))
        return DateFormatter.openRouterActivityDay.date(from: datePart)
    }
}

public extension OpenRouterAPIKey {
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return label
    }

    var totalUsage: Double {
        usage + byokUsage
    }

    var totalUsageDaily: Double {
        usageDaily + byokUsageDaily
    }

    var totalUsageWeekly: Double {
        usageWeekly + byokUsageWeekly
    }

    var totalUsageMonthly: Double {
        usageMonthly + byokUsageMonthly
    }

    var expirationDate: Date? {
        guard let expiresAt else { return nil }
        return ISO8601DateFormatter().date(from: expiresAt)
    }
}

private extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private extension DateFormatter {
    static let openRouterActivityDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.utc
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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

    public var usageAllTimeIncludingBYOK: Double {
        usageAllTime + byokUsageAllTime
    }

    public var usageDailyIncludingBYOK: Double {
        usageDaily + byokUsageDaily
    }

    public var usageWeeklyIncludingBYOK: Double {
        usageWeekly + byokUsageWeekly
    }

    public var usageMonthlyIncludingBYOK: Double {
        usageMonthly + byokUsageMonthly
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

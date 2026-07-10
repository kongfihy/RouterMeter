import Foundation

public struct SpendForecastSummary: Codable, Equatable, Sendable {
    public let monthToDateSpend: Double
    public let averageDailySpend: Double
    public let projectedMonthEndSpend: Double
    public let monthlyBudget: Double
    public let daysRemainingInMonth: Int
    public let paceChangeRatio: Double?
    public let isSpendSpike: Bool

    public var projectedBudgetDifference: Double? {
        guard monthlyBudget > 0 else { return nil }
        return projectedMonthEndSpend - monthlyBudget
    }

    public init(
        monthToDateSpend: Double,
        averageDailySpend: Double,
        projectedMonthEndSpend: Double,
        monthlyBudget: Double,
        daysRemainingInMonth: Int,
        paceChangeRatio: Double?,
        isSpendSpike: Bool
    ) {
        self.monthToDateSpend = monthToDateSpend
        self.averageDailySpend = averageDailySpend
        self.projectedMonthEndSpend = projectedMonthEndSpend
        self.monthlyBudget = monthlyBudget
        self.daysRemainingInMonth = daysRemainingInMonth
        self.paceChangeRatio = paceChangeRatio
        self.isSpendSpike = isSpendSpike
    }

    public static func make(
        snapshot: UsageSnapshot?,
        activitySummary: ActivityUsageSummary?,
        monthlyBudget: Double,
        now: Date = Date()
    ) -> SpendForecastSummary? {
        guard let activitySummary else { return nil }

        let average7Day = activitySummary.last7DaysUsage / Double(max(activitySummary.last7WindowDays, 1))
        let average30Day = activitySummary.last30DaysUsage / Double(max(activitySummary.last30WindowDays, 1))
        let averageDailySpend: Double
        if average7Day > 0, average30Day > 0 {
            averageDailySpend = (average7Day * 0.7) + (average30Day * 0.3)
        } else {
            averageDailySpend = max(average7Day, average30Day)
        }
        guard averageDailySpend > 0 else { return nil }

        let calendar = Calendar.openRouterUTC
        let day = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? day
        let daysRemaining = max(0, daysInMonth - day)
        let activityMonthToDateSpend = activitySummary.trend
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalUsage }
        let monthToDateSpend = max(snapshot?.usageMonthlyIncludingBYOK ?? 0, activityMonthToDateSpend)

        let projectedMonthEndSpend = monthToDateSpend + (averageDailySpend * Double(daysRemaining))
        let previous7DayAverage = previous7DayAverage(from: activitySummary, calendar: calendar)
        let paceChangeRatio = previous7DayAverage.flatMap { previousAverage in
            previousAverage > 0 ? (average7Day - previousAverage) / previousAverage : nil
        }
        let isSpendSpike = (paceChangeRatio ?? 0) >= 0.25 && activitySummary.last7DaysUsage >= 1

        return SpendForecastSummary(
            monthToDateSpend: monthToDateSpend,
            averageDailySpend: averageDailySpend,
            projectedMonthEndSpend: projectedMonthEndSpend,
            monthlyBudget: monthlyBudget,
            daysRemainingInMonth: daysRemaining,
            paceChangeRatio: paceChangeRatio,
            isSpendSpike: isSpendSpike
        )
    }

    private static func previous7DayAverage(
        from summary: ActivityUsageSummary,
        calendar: Calendar
    ) -> Double? {
        guard let latestDate = summary.latestDate else { return nil }
        guard
            let start = calendar.date(byAdding: .day, value: -13, to: latestDate),
            let end = calendar.date(byAdding: .day, value: -7, to: latestDate)
        else {
            return nil
        }

        let items = summary.trend.filter { $0.date >= start && $0.date <= end }
        guard !items.isEmpty else { return nil }
        return items.reduce(0) { $0 + $1.totalUsage } / 7
    }
}

public enum ModelCatalogChangeKind: String, Codable, Equatable, Sendable {
    case priceIncreased
    case priceDecreased
    case pricingChanged
    case contextChanged
    case expirationScheduled
    case unavailable
}

public struct ModelCatalogChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let modelID: String
    public let modelName: String
    public let kind: ModelCatalogChangeKind
    public let detectedAt: Date
    public let previousPromptPrice: Double?
    public let currentPromptPrice: Double?
    public let previousCompletionPrice: Double?
    public let currentCompletionPrice: Double?
    public let previousContextLength: Int?
    public let currentContextLength: Int?
    public let expirationDate: Date?

    public init(
        id: UUID = UUID(),
        modelID: String,
        modelName: String,
        kind: ModelCatalogChangeKind,
        detectedAt: Date,
        previousPromptPrice: Double? = nil,
        currentPromptPrice: Double? = nil,
        previousCompletionPrice: Double? = nil,
        currentCompletionPrice: Double? = nil,
        previousContextLength: Int? = nil,
        currentContextLength: Int? = nil,
        expirationDate: Date? = nil
    ) {
        self.id = id
        self.modelID = modelID
        self.modelName = modelName
        self.kind = kind
        self.detectedAt = detectedAt
        self.previousPromptPrice = previousPromptPrice
        self.currentPromptPrice = currentPromptPrice
        self.previousCompletionPrice = previousCompletionPrice
        self.currentCompletionPrice = currentCompletionPrice
        self.previousContextLength = previousContextLength
        self.currentContextLength = currentContextLength
        self.expirationDate = expirationDate
    }
}

public enum ModelCatalogChangeDetector {
    public static func detect(
        previous: [OpenRouterModel],
        current: [OpenRouterModel],
        trackedModelIDs: [String],
        detectedAt: Date = Date()
    ) -> [ModelCatalogChange] {
        let previousByID = indexed(previous)
        let currentByID = indexed(current)

        return trackedModelIDs.flatMap { trackedID -> [ModelCatalogChange] in
            let normalized = normalize(trackedID)
            guard let oldModel = previousByID[normalized] else { return [] }
            guard let newModel = currentByID[normalized] else {
                return [ModelCatalogChange(
                    modelID: trackedID,
                    modelName: oldModel.name,
                    kind: .unavailable,
                    detectedAt: detectedAt
                )]
            }

            var changes: [ModelCatalogChange] = []
            let oldPrompt = oldModel.pricing.promptPricePerMillion
            let newPrompt = newModel.pricing.promptPricePerMillion
            let oldCompletion = oldModel.pricing.completionPricePerMillion
            let newCompletion = newModel.pricing.completionPricePerMillion

            if priceChanged(oldPrompt, newPrompt) || priceChanged(oldCompletion, newCompletion) {
                changes.append(ModelCatalogChange(
                    modelID: trackedID,
                    modelName: newModel.name,
                    kind: priceChangeKind(
                        oldPrompt: oldPrompt,
                        newPrompt: newPrompt,
                        oldCompletion: oldCompletion,
                        newCompletion: newCompletion
                    ),
                    detectedAt: detectedAt,
                    previousPromptPrice: oldPrompt,
                    currentPromptPrice: newPrompt,
                    previousCompletionPrice: oldCompletion,
                    currentCompletionPrice: newCompletion
                ))
            }

            if oldModel.contextLength != newModel.contextLength {
                changes.append(ModelCatalogChange(
                    modelID: trackedID,
                    modelName: newModel.name,
                    kind: .contextChanged,
                    detectedAt: detectedAt,
                    previousContextLength: oldModel.contextLength,
                    currentContextLength: newModel.contextLength
                ))
            }

            if oldModel.expirationDateValue == nil, let expirationDate = newModel.expirationDateValue {
                changes.append(ModelCatalogChange(
                    modelID: trackedID,
                    modelName: newModel.name,
                    kind: .expirationScheduled,
                    detectedAt: detectedAt,
                    expirationDate: expirationDate
                ))
            }

            return changes
        }
    }

    private static func indexed(_ models: [OpenRouterModel]) -> [String: OpenRouterModel] {
        Dictionary(
            models.flatMap { model in
                [model.id, model.canonicalSlug ?? ""]
                    .map(normalize)
                    .filter { !$0.isEmpty }
                    .map { ($0, model) }
            },
            uniquingKeysWith: { existing, _ in existing }
        )
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func priceChanged(_ old: Double?, _ new: Double?) -> Bool {
        switch (old, new) {
        case let (.some(old), .some(new)):
            return abs(old - new) > max(0.000_001, abs(old) * 0.000_1)
        case (.none, .none):
            return false
        default:
            return true
        }
    }

    private static func priceChangeKind(
        oldPrompt: Double?,
        newPrompt: Double?,
        oldCompletion: Double?,
        newCompletion: Double?
    ) -> ModelCatalogChangeKind {
        let oldTotal = (oldPrompt ?? 0) + (oldCompletion ?? 0)
        let newTotal = (newPrompt ?? 0) + (newCompletion ?? 0)
        if newTotal > oldTotal { return .priceIncreased }
        if newTotal < oldTotal { return .priceDecreased }
        return .pricingChanged
    }
}

public enum KeyHealthIssueKind: String, Codable, Equatable, Sendable {
    case expired
    case expiringSoon
    case nearLimit
}

public struct KeyHealthIssue: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let keyName: String
    public let kind: KeyHealthIssueKind
    public let daysRemaining: Int?
    public let limitRemaining: Double?
    public let limit: Double?
    public let resetCadence: String?

    public init(
        id: String,
        keyName: String,
        kind: KeyHealthIssueKind,
        daysRemaining: Int? = nil,
        limitRemaining: Double? = nil,
        limit: Double? = nil,
        resetCadence: String? = nil
    ) {
        self.id = id
        self.keyName = keyName
        self.kind = kind
        self.daysRemaining = daysRemaining
        self.limitRemaining = limitRemaining
        self.limit = limit
        self.resetCadence = resetCadence
    }
}

public struct KeyHealthSummary: Codable, Equatable, Sendable {
    public let issues: [KeyHealthIssue]
    public let totalKeys: Int
    public let disabledKeys: Int
    public let currentResetCadence: String?

    public init(
        issues: [KeyHealthIssue],
        totalKeys: Int,
        disabledKeys: Int,
        currentResetCadence: String?
    ) {
        self.issues = issues
        self.totalKeys = totalKeys
        self.disabledKeys = disabledKeys
        self.currentResetCadence = currentResetCadence
    }

    public static func make(
        snapshot: UsageSnapshot?,
        apiKeys: [OpenRouterAPIKey],
        expiryWarningDays: Int = 14,
        nearLimitRatio: Double = 0.10,
        now: Date = Date()
    ) -> KeyHealthSummary {
        var issues: [KeyHealthIssue] = []

        if let snapshot {
            appendExpirationIssue(
                to: &issues,
                idPrefix: "current",
                keyName: snapshot.keyLabel,
                expirationDate: snapshot.keyExpirationDate,
                warningDays: expiryWarningDays,
                now: now
            )
            appendLimitIssue(
                to: &issues,
                idPrefix: "current",
                keyName: snapshot.keyLabel,
                limit: snapshot.keyLimit,
                remaining: snapshot.keyLimitRemaining,
                resetCadence: snapshot.keyLimitReset,
                nearLimitRatio: nearLimitRatio
            )
        }

        for key in apiKeys where !key.disabled {
            appendExpirationIssue(
                to: &issues,
                idPrefix: key.hash,
                keyName: key.displayName,
                expirationDate: key.expirationDate,
                warningDays: expiryWarningDays,
                now: now
            )
            appendLimitIssue(
                to: &issues,
                idPrefix: key.hash,
                keyName: key.displayName,
                limit: key.limit,
                remaining: key.limitRemaining,
                resetCadence: key.limitReset,
                nearLimitRatio: nearLimitRatio
            )
        }

        return KeyHealthSummary(
            issues: issues.sorted { lhs, rhs in
                issuePriority(lhs.kind) < issuePriority(rhs.kind)
            },
            totalKeys: apiKeys.isEmpty ? (snapshot == nil ? 0 : 1) : apiKeys.count,
            disabledKeys: apiKeys.filter(\.disabled).count,
            currentResetCadence: snapshot?.keyLimitReset
        )
    }

    private static func appendExpirationIssue(
        to issues: inout [KeyHealthIssue],
        idPrefix: String,
        keyName: String,
        expirationDate: Date?,
        warningDays: Int,
        now: Date
    ) {
        guard let expirationDate else { return }
        let days = Calendar.openRouterUTC.dateComponents([.day], from: now, to: expirationDate).day ?? 0
        if days < 0 {
            issues.append(KeyHealthIssue(
                id: "\(idPrefix)-expired",
                keyName: keyName,
                kind: .expired,
                daysRemaining: days
            ))
        } else if days <= warningDays {
            issues.append(KeyHealthIssue(
                id: "\(idPrefix)-expiring",
                keyName: keyName,
                kind: .expiringSoon,
                daysRemaining: days
            ))
        }
    }

    private static func appendLimitIssue(
        to issues: inout [KeyHealthIssue],
        idPrefix: String,
        keyName: String,
        limit: Double?,
        remaining: Double?,
        resetCadence: String?,
        nearLimitRatio: Double
    ) {
        guard let limit, limit > 0, let remaining, remaining / limit <= nearLimitRatio else { return }
        issues.append(KeyHealthIssue(
            id: "\(idPrefix)-near-limit",
            keyName: keyName,
            kind: .nearLimit,
            limitRemaining: remaining,
            limit: limit,
            resetCadence: resetCadence
        ))
    }

    private static func issuePriority(_ kind: KeyHealthIssueKind) -> Int {
        switch kind {
        case .expired: return 0
        case .expiringSoon: return 1
        case .nearLimit: return 2
        }
    }
}

private extension Calendar {
    static var openRouterUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

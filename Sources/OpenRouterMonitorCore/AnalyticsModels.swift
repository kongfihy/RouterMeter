import Foundation

public struct AnalyticsMetadataResponse: Decodable, Sendable {
    public let data: AnalyticsMetadata
}

public struct AnalyticsMetadata: Decodable, Sendable {
    public let metrics: [AnalyticsFieldDefinition]
    public let dimensions: [AnalyticsFieldDefinition]
    public let granularities: [AnalyticsFieldDefinition]
}

public struct AnalyticsFieldDefinition: Decodable, Sendable, Identifiable {
    public let name: String
    public let displayLabel: String?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case displayLabel = "display_label"
    }
}

public struct AnalyticsTimeRange: Encodable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    enum CodingKeys: String, CodingKey {
        case start
        case end
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: start), forKey: .start)
        try container.encode(formatter.string(from: end), forKey: .end)
    }
}

public struct AnalyticsOrderBy: Encodable, Sendable {
    public let field: String
    public let direction: String

    public init(field: String, direction: String = "desc") {
        self.field = field
        self.direction = direction
    }
}

public struct AnalyticsQueryRequest: Encodable, Sendable {
    public let metrics: [String]
    public let dimensions: [String]
    public let granularity: String?
    public let timeRange: AnalyticsTimeRange
    public let limit: Int
    public let orderBy: AnalyticsOrderBy?

    public init(
        metrics: [String],
        dimensions: [String],
        granularity: String?,
        timeRange: AnalyticsTimeRange,
        limit: Int,
        orderBy: AnalyticsOrderBy?
    ) {
        self.metrics = metrics
        self.dimensions = dimensions
        self.granularity = granularity
        self.timeRange = timeRange
        self.limit = limit
        self.orderBy = orderBy
    }

    enum CodingKeys: String, CodingKey {
        case metrics
        case dimensions
        case granularity
        case timeRange = "time_range"
        case limit
        case orderBy = "order_by"
    }
}

public struct AnalyticsQueryResponse: Decodable, Sendable {
    public let data: Payload

    public struct Payload: Decodable, Sendable {
        public let data: [[String: AnalyticsValue]]
        public let metadata: Metadata
        public let warnings: [String]?
    }

    public struct Metadata: Decodable, Sendable {
        public let queryTimeMilliseconds: Double
        public let rowCount: Int
        public let truncated: Bool

        enum CodingKeys: String, CodingKey {
            case queryTimeMilliseconds = "query_time_ms"
            case rowCount = "row_count"
            case truncated
        }
    }
}

public enum AnalyticsValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnalyticsValue])
    case object([String: AnalyticsValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnalyticsValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnalyticsValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported analytics value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    public var intValue: Int? {
        doubleValue.map(Int.init)
    }
}

public struct AnalyticsUsageSummary: Codable, Equatable, Sendable {
    public let periodStart: Date
    public let periodEnd: Date
    public let capturedAt: Date
    public let usage: Double
    public let requestCount: Int
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int

    public init(
        periodStart: Date,
        periodEnd: Date,
        capturedAt: Date = Date(),
        usage: Double,
        requestCount: Int,
        promptTokens: Int,
        completionTokens: Int,
        reasoningTokens: Int
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.capturedAt = capturedAt
        self.usage = usage
        self.requestCount = requestCount
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
    }

    public var totalTokens: Int {
        promptTokens + completionTokens + reasoningTokens
    }
}

public struct GenerationLogSummary: Equatable, Identifiable, Sendable {
    public let generationID: String
    public let occurredAt: Date?
    public let model: String
    public let totalCost: Double
    public let promptTokens: Int
    public let completionTokens: Int
    public let reasoningTokens: Int

    public var id: String { generationID }

    public init(
        generationID: String,
        occurredAt: Date?,
        model: String,
        totalCost: Double,
        promptTokens: Int,
        completionTokens: Int,
        reasoningTokens: Int
    ) {
        self.generationID = generationID
        self.occurredAt = occurredAt
        self.model = model
        self.totalCost = totalCost
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
    }
}

public struct OpenRouterGenerationResponse: Decodable, Sendable {
    public let data: OpenRouterGeneration
}

public struct OpenRouterGeneration: Decodable, Sendable {
    public let id: String
    public let createdAt: String?
    public let model: String?
    public let providerName: String?
    public let totalCost: Double?
    public let usage: Double?
    public let tokensPrompt: Int?
    public let tokensCompletion: Int?
    public let nativeTokensReasoning: Int?
    public let latency: Double?
    public let generationTime: Double?
    public let finishReason: String?
    public let nativeFinishReason: String?
    public let cancelled: Bool?
    public let streamed: Bool?
    public let isBYOK: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case model
        case providerName = "provider_name"
        case totalCost = "total_cost"
        case usage
        case tokensPrompt = "tokens_prompt"
        case tokensCompletion = "tokens_completion"
        case nativeTokensReasoning = "native_tokens_reasoning"
        case latency
        case generationTime = "generation_time"
        case finishReason = "finish_reason"
        case nativeFinishReason = "native_finish_reason"
        case cancelled
        case streamed
        case isBYOK = "is_byok"
    }

    public var parsedCreatedAt: Date? {
        guard let createdAt else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: createdAt)
            ?? ISO8601DateFormatter().date(from: createdAt)
    }
}

public enum GenerationLogParser {
    public static func parse(
        rows: [[String: AnalyticsValue]],
        generationDimension: String,
        modelDimension: String?,
        costMetric: String?,
        promptMetric: String?,
        completionMetric: String?,
        reasoningMetric: String?
    ) -> [GenerationLogSummary] {
        rows.compactMap { row in
            guard let generationID = row[generationDimension]?.stringValue, !generationID.isEmpty else {
                return nil
            }

            let model = modelDimension.flatMap { row[$0]?.stringValue } ?? "Unknown model"
            return GenerationLogSummary(
                generationID: generationID,
                occurredAt: dateValue(in: row) ?? dateValue(fromGenerationID: generationID),
                model: model,
                totalCost: costMetric.flatMap { row[$0]?.doubleValue } ?? 0,
                promptTokens: promptMetric.flatMap { row[$0]?.intValue } ?? 0,
                completionTokens: completionMetric.flatMap { row[$0]?.intValue } ?? 0,
                reasoningTokens: reasoningMetric.flatMap { row[$0]?.intValue } ?? 0
            )
        }
    }

    private static func dateValue(fromGenerationID generationID: String) -> Date? {
        // IDs can use prefixes such as `gen-...` and `gen-stt-...`; locate the
        // Unix timestamp component instead of assuming it is always second.
        guard let seconds = generationID
            .split(separator: "-")
            .compactMap({ TimeInterval($0) })
            .first(where: { $0 > 1_000_000_000 }) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func dateValue(in row: [String: AnalyticsValue]) -> Date? {
        let likelyDateKeys = row.keys.filter { key in
            let normalized = key.lowercased()
            return normalized.contains("date")
                || normalized.contains("time")
                || normalized.contains("hour")
                || normalized.contains("minute")
                || normalized == "created_at"
        }

        for key in likelyDateKeys.sorted() {
            guard let raw = row[key]?.stringValue else { continue }
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
                return date
            }
        }
        return nil
    }

}

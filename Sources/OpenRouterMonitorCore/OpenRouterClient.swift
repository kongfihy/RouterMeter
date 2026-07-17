import Foundation

public enum OpenRouterClientError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey
    case unauthorized
    case forbidden
    case rateLimited
    case paymentRequired
    case invalidResponse
    case requestRejected(Int, String)
    case analyticsUnavailable(String)
    case serverError(Int)
    case transport(String)
    case encoding(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an OpenRouter API key in Settings."
        case .unauthorized:
            return "OpenRouter rejected the API key."
        case .forbidden:
            return "This key is not allowed to access the requested endpoint."
        case .rateLimited:
            return "OpenRouter rate limited the refresh request."
        case .paymentRequired:
            return "OpenRouter reported insufficient account credits."
        case .invalidResponse:
            return "OpenRouter returned an invalid response."
        case .requestRejected(let statusCode, let message):
            return "OpenRouter rejected the request (HTTP \(statusCode)): \(message)"
        case .analyticsUnavailable(let message):
            return message
        case .serverError(let code):
            return "OpenRouter returned server error \(code)."
        case .transport(let message):
            return message
        case .encoding(let message):
            return "Could not create OpenRouter request: \(message)"
        case .decoding(let message):
            return "Could not read OpenRouter response: \(message)"
        }
    }
}

public protocol OpenRouterFetching: Sendable {
    func fetchKey(apiKey: String) async throws -> OpenRouterKeyResponse
    func fetchCredits(apiKey: String) async throws -> OpenRouterCreditsResponse
    func fetchUsageSnapshot(apiKey: String, includeCredits: Bool) async throws -> UsageSnapshot
    func fetchActivity(apiKey: String) async throws -> [OpenRouterActivityItem]
    func fetchKeys(apiKey: String) async throws -> [OpenRouterAPIKey]
    func fetchModels() async throws -> [OpenRouterModel]
}

public final class OpenRouterClient: OpenRouterFetching, @unchecked Sendable {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    public func fetchUsageSnapshot(apiKey: String, includeCredits: Bool) async throws -> UsageSnapshot {
        let keyResponse = try await fetchKey(apiKey: apiKey)
        let creditsResponse = includeCredits ? try await fetchCredits(apiKey: apiKey) : nil
        return UsageSnapshot.make(
            keyResponse: keyResponse,
            creditsResponse: creditsResponse
        )
    }

    public func fetchKey(apiKey: String) async throws -> OpenRouterKeyResponse {
        let trimmedKey = try validatedAPIKey(apiKey)
        return try await get(path: "key", apiKey: trimmedKey)
    }

    public func fetchCredits(apiKey: String) async throws -> OpenRouterCreditsResponse {
        let trimmedKey = try validatedAPIKey(apiKey)
        return try await get(path: "credits", apiKey: trimmedKey)
    }

    public func fetchActivity(apiKey: String) async throws -> [OpenRouterActivityItem] {
        let trimmedKey = try validatedAPIKey(apiKey)
        let response: OpenRouterActivityResponse = try await get(path: "activity", apiKey: trimmedKey)
        return response.data
    }

    public func fetchKeys(apiKey: String) async throws -> [OpenRouterAPIKey] {
        let trimmedKey = try validatedAPIKey(apiKey)
        let response: OpenRouterAPIKeysResponse = try await get(
            path: "keys",
            apiKey: trimmedKey,
            queryItems: [URLQueryItem(name: "include_disabled", value: "true")]
        )
        return response.data
    }

    public func fetchModels() async throws -> [OpenRouterModel] {
        let response: OpenRouterModelsResponse = try await get(path: "models")
        return response.data
    }

    public func fetchAnalyticsMetadata(apiKey: String) async throws -> AnalyticsMetadata {
        let trimmedKey = try validatedAPIKey(apiKey)
        let response: AnalyticsMetadataResponse = try await get(path: "analytics/meta", apiKey: trimmedKey)
        return response.data
    }

    public func fetchUsageSummary(
        apiKey: String,
        start: Date,
        end: Date = Date()
    ) async throws -> AnalyticsUsageSummary {
        let trimmedKey = try validatedAPIKey(apiKey)
        let metadata = try await fetchAnalyticsMetadata(apiKey: trimmedKey)
        let metricNames = Set(metadata.metrics.map { $0.name })
        let costMetric = firstAvailable(
            in: metricNames,
            candidates: ["total_usage", "total_cost", "usage"]
        )
        let requestMetric = firstAvailable(
            in: metricNames,
            candidates: ["request_count", "requests"]
        )
        let promptMetric = firstAvailable(
            in: metricNames,
            candidates: ["prompt_tokens", "tokens_prompt"]
        )
        let completionMetric = firstAvailable(
            in: metricNames,
            candidates: ["completion_tokens", "tokens_completion"]
        )
        let reasoningMetric = firstAvailable(
            in: metricNames,
            candidates: ["reasoning_tokens", "tokens_reasoning", "native_tokens_reasoning"]
        )
        let metrics = uniqueStrings([costMetric, requestMetric, promptMetric, completionMetric, reasoningMetric].compactMap { $0 })
        guard !metrics.isEmpty else {
            throw OpenRouterClientError.analyticsUnavailable(
                "OpenRouter Analytics did not report any compatible usage metrics."
            )
        }

        let request = AnalyticsQueryRequest(
            metrics: metrics,
            dimensions: [],
            granularity: nil,
            timeRange: AnalyticsTimeRange(start: start, end: end),
            limit: 1,
            orderBy: nil
        )
        let response: AnalyticsQueryResponse = try await post(
            path: "analytics/query",
            apiKey: trimmedKey,
            body: request
        )
        let row = response.data.data.first ?? [:]
        return AnalyticsUsageSummary(
            periodStart: start,
            periodEnd: end,
            usage: costMetric.flatMap { row[$0]?.doubleValue } ?? 0,
            requestCount: requestMetric.flatMap { row[$0]?.intValue } ?? 0,
            promptTokens: promptMetric.flatMap { row[$0]?.intValue } ?? 0,
            completionTokens: completionMetric.flatMap { row[$0]?.intValue } ?? 0,
            reasoningTokens: reasoningMetric.flatMap { row[$0]?.intValue } ?? 0
        )
    }

    public func fetchRecentGenerationLogs(
        apiKey: String,
        since: Date,
        until: Date = Date(),
        limit: Int = 100
    ) async throws -> [GenerationLogSummary] {
        let trimmedKey = try validatedAPIKey(apiKey)
        let metadata = try await fetchAnalyticsMetadata(apiKey: trimmedKey)
        let dimensionNames = Set(metadata.dimensions.map { $0.name })
        let metricNames = Set(metadata.metrics.map { $0.name })

        guard let generationDimension = firstAvailable(
            in: dimensionNames,
            candidates: ["generation_id", "generation"]
        ) else {
            throw OpenRouterClientError.analyticsUnavailable(
                "OpenRouter Analytics does not currently expose generation-level data for this account."
            )
        }

        let costMetric = firstAvailable(
            in: metricNames,
            candidates: ["total_usage", "total_cost", "usage"]
        )
        let requestMetric = firstAvailable(
            in: metricNames,
            candidates: ["request_count", "requests"]
        )
        let metrics = uniqueStrings([costMetric, requestMetric].compactMap { $0 })
        guard !metrics.isEmpty else {
            throw OpenRouterClientError.analyticsUnavailable(
                "OpenRouter Analytics did not report any compatible generation metrics."
            )
        }

        // Generation-level queries become slow or fail when combined with a
        // second dimension or time granularity. OpenRouter can order this
        // lightweight query by cost reliably, but that would otherwise hide
        // recent low-cost generations. Fetch the largest supported candidate
        // set and sort it locally by the timestamp embedded in generation IDs.
        let request = AnalyticsQueryRequest(
            metrics: metrics,
            dimensions: [generationDimension],
            granularity: nil,
            timeRange: AnalyticsTimeRange(start: since, end: until),
            limit: 500,
            orderBy: costMetric.map { AnalyticsOrderBy(field: $0) }
        )
        let response: AnalyticsQueryResponse = try await post(
            path: "analytics/query",
            apiKey: trimmedKey,
            body: request
        )

        let requestedLimit = min(max(limit, 1), 500)
        let parsed = GenerationLogParser.parse(
            rows: response.data.data,
            generationDimension: generationDimension,
            modelDimension: nil,
            costMetric: costMetric,
            promptMetric: nil,
            completionMetric: nil,
            reasoningMetric: nil
        )
        return Array(
            parsed.sorted { lhs, rhs in
                switch (lhs.occurredAt, rhs.occurredAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.generationID > rhs.generationID
                }
            }
            .prefix(requestedLimit)
        )
    }

    public func fetchGeneration(apiKey: String, id: String) async throws -> OpenRouterGeneration {
        let trimmedKey = try validatedAPIKey(apiKey)
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { throw OpenRouterClientError.invalidResponse }
        let response: OpenRouterGenerationResponse = try await get(
            path: "generation",
            apiKey: trimmedKey,
            queryItems: [URLQueryItem(name: "id", value: trimmedID)]
        )
        return response.data
    }

    public func fetchGenerations(
        apiKey: String,
        ids: [String],
        maximumConcurrentRequests: Int = 4
    ) async -> [OpenRouterGeneration] {
        let batchSize = max(1, maximumConcurrentRequests)
        var results: [OpenRouterGeneration] = []
        var startIndex = 0

        while startIndex < ids.count {
            let endIndex = min(startIndex + batchSize, ids.count)
            let batch = Array(ids[startIndex..<endIndex])
            let batchResults = await withTaskGroup(of: OpenRouterGeneration?.self) { group in
                for id in batch {
                    group.addTask { [self] in
                        try? await fetchGeneration(apiKey: apiKey, id: id)
                    }
                }

                var values: [OpenRouterGeneration] = []
                for await value in group {
                    if let value { values.append(value) }
                }
                return values
            }
            results.append(contentsOf: batchResults)
            startIndex = endIndex
        }

        return results
    }

    private func validatedAPIKey(_ apiKey: String) throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }
        return trimmedKey
    }

    private func firstAvailable(in available: Set<String>, candidates: [String]) -> String? {
        candidates.first(where: available.contains)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func get<Response: Decodable>(
        path: String,
        apiKey: String? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(
            method: "GET",
            path: path,
            apiKey: apiKey,
            queryItems: queryItems,
            body: nil
        )
    }

    private func post<Response: Decodable, Body: Encodable>(
        path: String,
        apiKey: String,
        body: Body
    ) async throws -> Response {
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw OpenRouterClientError.encoding(error.localizedDescription)
        }
        return try await request(
            method: "POST",
            path: path,
            apiKey: apiKey,
            queryItems: [],
            body: bodyData
        )
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        apiKey: String?,
        queryItems: [URLQueryItem],
        body: Data?
    ) async throws -> Response {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        guard let url = urlComponents?.url else {
            throw OpenRouterClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw OpenRouterClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw OpenRouterClientError.decoding(error.localizedDescription)
            }
        case 401:
            throw OpenRouterClientError.unauthorized
        case 402:
            throw OpenRouterClientError.paymentRequired
        case 403:
            throw OpenRouterClientError.forbidden
        case 429:
            throw OpenRouterClientError.rateLimited
        case 500..<600:
            throw OpenRouterClientError.serverError(httpResponse.statusCode)
        default:
            if let apiError = try? decoder.decode(OpenRouterAPIErrorResponse.self, from: data) {
                throw OpenRouterClientError.requestRejected(httpResponse.statusCode, apiError.error.message)
            }
            throw OpenRouterClientError.invalidResponse
        }
    }
}

private struct OpenRouterAPIErrorResponse: Decodable {
    let error: OpenRouterAPIErrorBody
}

private struct OpenRouterAPIErrorBody: Decodable {
    let message: String
}

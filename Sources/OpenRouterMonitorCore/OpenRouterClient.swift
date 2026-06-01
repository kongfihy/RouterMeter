import Foundation

public enum OpenRouterClientError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey
    case unauthorized
    case forbidden
    case rateLimited
    case paymentRequired
    case invalidResponse
    case serverError(Int)
    case transport(String)
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
        case .serverError(let code):
            return "OpenRouter returned server error \(code)."
        case .transport(let message):
            return message
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
}

public final class OpenRouterClient: OpenRouterFetching, @unchecked Sendable {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
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
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }
        return try await get(path: "key", apiKey: trimmedKey)
    }

    public func fetchCredits(apiKey: String) async throws -> OpenRouterCreditsResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }
        return try await get(path: "credits", apiKey: trimmedKey)
    }

    public func fetchActivity(apiKey: String) async throws -> [OpenRouterActivityItem] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OpenRouterClientError.missingAPIKey }
        let response: OpenRouterActivityResponse = try await get(path: "activity", apiKey: trimmedKey)
        return response.data
    }

    private func get<Response: Decodable>(path: String, apiKey: String) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
            throw OpenRouterClientError.invalidResponse
        }
    }
}

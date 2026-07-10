import Foundation
import OpenRouterMonitorCore

@main
struct CoreChecks {
    static func main() async throws {
        try checkAPIDecoding()
        checkCalculations()
        checkAlertEvaluator()
        checkIntelligenceModels()
        try await checkClientKeyOnlySnapshot()
        try await checkClientManagementCreditsSnapshot()
        try await checkClientModels()
        await checkClientHTTPFailures()
        await checkMalformedResponse()
        await checkTransportFailure()
        print("All OpenRouterMonitorCore checks passed.")
    }

    private static func checkAPIDecoding() throws {
        let keyResponse = try JSONDecoder().decode(OpenRouterKeyResponse.self, from: keyBody)
        expect(keyResponse.data.label == "Personal Key", "key label decodes")
        expect(keyResponse.data.limit == 50, "key limit decodes")
        expect(keyResponse.data.limitRemaining == 37.5, "key remaining decodes")
        expect(keyResponse.data.usageDaily == 0.86, "daily usage decodes")
        expect(keyResponse.data.expiresAt == "2027-12-31T23:59:59Z", "current key expiry decodes")

        let creditsResponse = try JSONDecoder().decode(OpenRouterCreditsResponse.self, from: creditsBody)
        expect(creditsResponse.data.totalCredits == 100.5, "total credits decodes")
        expect(creditsResponse.data.totalUsage == 25.75, "total usage decodes")

        let keysResponse = try JSONDecoder().decode(OpenRouterAPIKeysResponse.self, from: keysBody)
        expect(keysResponse.data.count == 2, "api key list decodes")
        expect(keysResponse.data[0].displayName == "Production Key", "api key display name")
        expect(approximatelyEqual(keysResponse.data[0].totalUsageMonthly, 17.5), "api key monthly total includes BYOK")

        let modelsResponse = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: modelsBody)
        expect(modelsResponse.data.count == 2, "model list decodes")
        expect(modelsResponse.data[0].id == "openai/gpt-4.1", "model id decodes")
        expect(modelsResponse.data[0].name == "GPT-4.1", "model name decodes")
        expect(approximatelyEqual(modelsResponse.data[0].pricing.promptPricePerMillion, 2), "prompt price normalizes per million")
        expect(approximatelyEqual(modelsResponse.data[0].pricing.completionPricePerMillion, 8), "completion price normalizes per million")
        expect(modelsResponse.data[0].expirationDate == "2028-01-01T00:00:00Z", "model expiration decodes")

        let activityResponse = try JSONDecoder().decode(OpenRouterActivityResponse.self, from: activityBody)
        expect(activityResponse.data.count == 2, "activity items decode")
        expect(activityResponse.data[0].model == "openai/gpt-4.1", "activity model decodes")
        expect(activityResponse.data[0].promptTokens == 50, "activity tokens decode")

        let summaries = ModelUsageSummary.aggregate(activityItems: activityResponse.data)
        expect(summaries.count == 1, "activity aggregates by model")
        expect(summaries[0].requests == 8, "activity request totals aggregate")
        expect(approximatelyEqual(summaries[0].usage, 0.039), "activity usage and BYOK totals aggregate")

        let activityUsage = ActivityUsageSummary.aggregate(activityItems: activityResponse.data)
        expect(approximatelyEqual(activityUsage?.latestDayUsage, 0.012), "latest day usage includes BYOK")
        expect(approximatelyEqual(activityUsage?.last7DaysUsage, 0.039), "last 7 day usage includes BYOK")
        expect(approximatelyEqual(activityUsage?.last30DaysByokUsage, 0.015), "last 30 day BYOK aggregate")
        expect(activityUsage?.last30DaysRequests == 8, "last 30 day requests aggregate")
        expect(activityUsage?.trend.count == 2, "trend groups by day")

        let burnDown = CreditBurnDownSummary.make(
            snapshot: makeSnapshot(totalCredits: 100, accountTotalUsage: 25),
            activitySummary: activityUsage
        )
        expect(approximatelyEqual(burnDown?.remainingCredits, 75), "burn down remaining credits")
        expect((burnDown?.estimatedDaysRemaining ?? 0) > 0, "burn down days remaining")
    }

    private static func checkCalculations() {
        let snapshot = makeSnapshot(totalCredits: 100, accountTotalUsage: 25, usageDaily: 1.25)
        let usd = MoneyFormatter(currency: .usd, usdToGBP: 0.8)
        let gbp = MoneyFormatter(currency: .gbp, usdToGBP: 0.8)

        expect(snapshot.accountRemainingCredits == 75, "remaining balance computes")
        expect(snapshot.accountPercentRemaining == 0.75, "percent remaining computes")
        expect(usd.string(fromUSDCredits: 12.5) == "$12.50", "USD formatting")
        expect(gbp.string(fromUSDCredits: 12.5) == "£10.00", "GBP formatting")
        expect(MenuBarTitleBuilder.title(snapshot: snapshot, mode: .balanceRemaining, moneyFormatter: usd) == "OR $75.00", "balance title")
        expect(MenuBarTitleBuilder.title(snapshot: snapshot, mode: .percentRemaining, moneyFormatter: usd) == "OR 75%", "percent title")
        expect(MenuBarTitleBuilder.title(snapshot: snapshot, mode: .todaySpend, moneyFormatter: usd) == "OR $1.25 today", "today title")

        let byokSnapshot = makeSnapshot(usageDaily: 1.25, byokUsageDaily: 0.75)
        expect(MenuBarTitleBuilder.title(snapshot: byokSnapshot, mode: .todaySpend, moneyFormatter: usd) == "OR $2.00 today", "today title includes BYOK")
    }

    private static func checkAlertEvaluator() {
        let evaluator = AlertEvaluator()
        let settings = BudgetSettings(lowBalanceThreshold: 10, criticalBalanceThreshold: 2, dailyBudget: 2, monthlyBudget: 50)
        let snapshot = makeSnapshot(totalCredits: 100, accountTotalUsage: 91, usageDaily: 3)

        let first = evaluator.evaluate(snapshot: snapshot, settings: settings, previouslyActive: [])
        expect(first.newAlerts == [.lowBalance, .dailyBudget], "new active alerts emit")

        let second = evaluator.evaluate(snapshot: snapshot, settings: settings, previouslyActive: first.activeAlerts)
        expect(second.newAlerts.isEmpty, "active alerts are not repeated")

        let critical = evaluator.evaluate(
            snapshot: makeSnapshot(totalCredits: 100, accountTotalUsage: 99),
            settings: settings,
            previouslyActive: []
        )
        expect(critical.newAlerts == [.criticalBalance], "critical balance suppresses low balance")
    }

    private static func checkIntelligenceModels() {
        let calendar = utcCalendar
        let now = makeDate("2026-07-10T12:00:00Z")
        let trend = (0..<14).map { offset -> ActivityDaySummary in
            let date = calendar.date(byAdding: .day, value: offset - 13, to: now)!
            let usage = offset < 7 ? 1.0 : 2.0
            return ActivityDaySummary(
                date: date,
                openRouterUsage: usage,
                byokUsage: 0,
                requests: 10,
                totalTokens: 1_000
            )
        }
        let activity = ActivityUsageSummary(
            trend: trend,
            latestDate: trend.last?.date,
            latestDayUsage: 2,
            latestDayByokUsage: 0,
            last7DaysUsage: 14,
            last7DaysByokUsage: 0,
            last7WindowDays: 7,
            last30DaysUsage: 21,
            last30DaysByokUsage: 0,
            last30WindowDays: 30,
            last30DaysRequests: 140,
            last30DaysTokens: 14_000
        )
        let forecast = SpendForecastSummary.make(
            snapshot: makeSnapshot(usageMonthly: 10),
            activitySummary: activity,
            monthlyBudget: 30,
            now: now
        )
        expect(approximatelyEqual(forecast?.monthToDateSpend, 17), "forecast uses the richer month-to-date source")
        expect((forecast?.projectedMonthEndSpend ?? 0) > 30, "forecast projects remaining month")
        expect(approximatelyEqual(forecast?.paceChangeRatio, 1), "forecast compares consecutive weeks")
        expect(forecast?.isSpendSpike == true, "forecast flags material spend spike")

        let previousModel = OpenRouterModel(
            id: "openai/gpt-4.1",
            canonicalSlug: nil,
            name: "GPT-4.1",
            description: nil,
            contextLength: 100_000,
            pricing: OpenRouterModelPricing(
                prompt: "0.000002",
                completion: "0.000008",
                request: nil,
                image: nil,
                inputCacheRead: nil
            )
        )
        let currentModel = OpenRouterModel(
            id: "openai/gpt-4.1",
            canonicalSlug: nil,
            name: "GPT-4.1",
            description: nil,
            contextLength: 200_000,
            pricing: OpenRouterModelPricing(
                prompt: "0.000003",
                completion: "0.000008",
                request: nil,
                image: nil,
                inputCacheRead: nil
            ),
            expirationDate: "2027-01-01T00:00:00Z"
        )
        let modelChanges = ModelCatalogChangeDetector.detect(
            previous: [previousModel],
            current: [currentModel],
            trackedModelIDs: [previousModel.id],
            detectedAt: now
        )
        expect(modelChanges.map(\.kind).contains(.priceIncreased), "model watch detects price increase")
        expect(modelChanges.map(\.kind).contains(.contextChanged), "model watch detects context change")
        expect(modelChanges.map(\.kind).contains(.expirationScheduled), "model watch detects scheduled expiration")
        let unavailable = ModelCatalogChangeDetector.detect(
            previous: [previousModel],
            current: [],
            trackedModelIDs: [previousModel.id],
            detectedAt: now
        )
        expect(unavailable.first?.kind == .unavailable, "model watch detects catalog removal")

        let expiringSnapshot = makeSnapshot(
            keyLimit: 100,
            keyLimitRemaining: 5,
            keyLimitReset: "monthly",
            keyExpiresAt: "2026-07-17T12:00:00Z"
        )
        let disabledKey = OpenRouterAPIKey(
            hash: "disabled",
            name: "Disabled",
            label: "disabled",
            disabled: true,
            limit: 10,
            limitRemaining: 10,
            limitReset: nil,
            usage: 0,
            usageDaily: 0,
            usageWeekly: 0,
            usageMonthly: 0,
            byokUsage: 0,
            byokUsageDaily: 0,
            byokUsageWeekly: 0,
            byokUsageMonthly: 0,
            includeBYOKInLimit: false,
            expiresAt: nil
        )
        let keyHealth = KeyHealthSummary.make(
            snapshot: expiringSnapshot,
            apiKeys: [disabledKey],
            expiryWarningDays: 14,
            now: now
        )
        expect(keyHealth.issues.map(\.kind).contains(.expiringSoon), "key health detects upcoming expiry")
        expect(keyHealth.issues.map(\.kind).contains(.nearLimit), "key health detects near limit")
        expect(keyHealth.disabledKeys == 1, "key health counts disabled keys")
    }

    private static func checkClientKeyOnlySnapshot() async throws {
        let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { request in
            expect(request.url?.path == "/key", "key endpoint requested")
            return response(statusCode: 200, body: keyBody)
        })

        let snapshot = try await client.fetchUsageSnapshot(apiKey: "sk-test", includeCredits: false)
        expect(snapshot.keyLabel == "Personal Key", "client decodes key label")
        expect(snapshot.usageDaily == 0.86, "client decodes daily usage")
        expect(snapshot.totalCredits == nil, "key-only refresh has no credits")
    }

    private static func checkClientManagementCreditsSnapshot() async throws {
        let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { request in
            switch request.url?.path {
            case "/key":
                return response(statusCode: 200, body: keyBody)
            case "/credits":
                return response(statusCode: 200, body: creditsBody)
            case "/activity":
                return response(statusCode: 200, body: activityBody)
            case "/keys":
                return response(statusCode: 200, body: keysBody)
            default:
                return response(statusCode: 404, body: Data())
            }
        })

        let snapshot = try await client.fetchUsageSnapshot(apiKey: "sk-test", includeCredits: true)
        expect(snapshot.totalCredits == 100.5, "credits refresh total credits")
        expect(snapshot.accountTotalUsage == 25.75, "credits refresh total usage")
        expect(snapshot.accountRemainingCredits == 74.75, "credits refresh remaining")

        let activity = try await client.fetchActivity(apiKey: "sk-test")
        expect(activity.count == 2, "client fetches activity")

        let keys = try await client.fetchKeys(apiKey: "sk-test")
        expect(keys.count == 2, "client fetches key list")
    }

    private static func checkClientModels() async throws {
        let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { request in
            expect(request.url?.path == "/models", "models endpoint requested")
            expect(request.value(forHTTPHeaderField: "Authorization") == nil, "models request does not require auth header")
            return response(statusCode: 200, body: modelsBody)
        })

        let models = try await client.fetchModels()
        expect(models.count == 2, "client fetches model list")
        expect(models[1].canonicalSlug == "anthropic/claude-sonnet-4-20250514", "client decodes canonical slug")
    }

    private static func checkClientHTTPFailures() async {
        let cases: [(Int, OpenRouterClientError)] = [
            (401, .unauthorized),
            (403, .forbidden),
            (429, .rateLimited),
            (500, .serverError(500))
        ]

        for testCase in cases {
            let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { _ in
                response(statusCode: testCase.0, body: Data())
            })

            do {
                _ = try await client.fetchUsageSnapshot(apiKey: "sk-test", includeCredits: false)
                fail("Expected \(testCase.1)")
            } catch let error as OpenRouterClientError {
                expect(error == testCase.1, "maps HTTP \(testCase.0)")
            } catch {
                fail("Unexpected error: \(error)")
            }
        }
    }

    private static func checkMalformedResponse() async {
        let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { _ in
            response(statusCode: 200, body: Data("{".utf8))
        })

        do {
            _ = try await client.fetchUsageSnapshot(apiKey: "sk-test", includeCredits: false)
            fail("Expected decoding error")
        } catch let error as OpenRouterClientError {
            if case .decoding = error {
                return
            }
            fail("Expected decoding error, got \(error)")
        } catch {
            fail("Unexpected error: \(error)")
        }
    }

    private static func checkTransportFailure() async {
        let client = OpenRouterClient(baseURL: URL(string: "https://example.test")!, urlSession: makeSession { _ in
            throw URLError(.timedOut)
        })

        do {
            _ = try await client.fetchUsageSnapshot(apiKey: "sk-test", includeCredits: false)
            fail("Expected transport error")
        } catch let error as OpenRouterClientError {
            if case .transport = error {
                return
            }
            fail("Expected transport error, got \(error)")
        } catch {
            fail("Unexpected error: \(error)")
        }
    }
}

private let keyBody = Data("""
{
  "data": {
    "label": "Personal Key",
    "limit": 50,
    "limit_reset": null,
    "limit_remaining": 37.5,
    "include_byok_in_limit": false,
    "usage": 12.5,
    "usage_daily": 0.86,
    "usage_weekly": 4.21,
    "usage_monthly": 12.5,
    "byok_usage": 0,
    "byok_usage_daily": 0,
    "byok_usage_weekly": 0,
    "byok_usage_monthly": 0,
    "is_free_tier": false,
    "is_management_key": false,
    "expires_at": "2027-12-31T23:59:59Z"
  }
}
""".utf8)

private let creditsBody = Data("""
{
  "data": {
    "total_credits": 100.5,
    "total_usage": 25.75
  }
}
""".utf8)

private let activityBody = Data("""
{
  "data": [
    {
      "byok_usage_inference": 0.012,
      "completion_tokens": 125,
      "date": "2025-08-24",
      "endpoint_id": "550e8400-e29b-41d4-a716-446655440000",
      "model": "openai/gpt-4.1",
      "model_permaslug": "openai/gpt-4.1-2025-04-14",
      "prompt_tokens": 50,
      "provider_name": "OpenAI",
      "reasoning_tokens": 25,
      "requests": 5,
      "usage": 0.015
    },
    {
      "byok_usage_inference": 0.003,
      "completion_tokens": 75,
      "date": "2025-08-25",
      "endpoint_id": "550e8400-e29b-41d4-a716-446655440000",
      "model": "openai/gpt-4.1",
      "model_permaslug": "openai/gpt-4.1-2025-04-14",
      "prompt_tokens": 35,
      "provider_name": "OpenAI",
      "reasoning_tokens": 10,
      "requests": 3,
      "usage": 0.009
    }
  ]
}
""".utf8)

private let keysBody = Data("""
{
  "data": [
    {
      "hash": "abc123",
      "name": "Production Key",
      "label": "sk-or-v1-pro...123",
      "disabled": false,
      "limit": 100,
      "limit_remaining": 82.5,
      "limit_reset": "monthly",
      "usage": 15,
      "usage_daily": 1.5,
      "usage_weekly": 5,
      "usage_monthly": 15,
      "byok_usage": 2.5,
      "byok_usage_daily": 0.2,
      "byok_usage_weekly": 0.8,
      "byok_usage_monthly": 2.5,
      "include_byok_in_limit": false,
      "expires_at": "2027-12-31T23:59:59Z"
    },
    {
      "hash": "def456",
      "name": null,
      "label": "sk-or-v1-dev...456",
      "disabled": true,
      "limit": 50,
      "limit_remaining": 12.75,
      "limit_reset": "monthly",
      "usage": 33,
      "usage_daily": 0.4,
      "usage_weekly": 2,
      "usage_monthly": 10,
      "byok_usage": 0,
      "byok_usage_daily": 0,
      "byok_usage_weekly": 0,
      "byok_usage_monthly": 0,
      "include_byok_in_limit": false,
      "expires_at": null
    }
  ]
}
""".utf8)

private let modelsBody = Data("""
{
  "data": [
    {
      "id": "openai/gpt-4.1",
      "canonical_slug": "openai/gpt-4.1-2025-04-14",
      "name": "GPT-4.1",
      "description": "A flagship OpenAI model.",
      "context_length": 1047576,
      "created": 1747000000,
      "expiration_date": "2028-01-01T00:00:00Z",
      "pricing": {
        "prompt": "0.000002",
        "completion": "0.000008",
        "image": "0",
        "request": "0"
      }
    },
    {
      "id": "anthropic/claude-sonnet-4",
      "canonical_slug": "anthropic/claude-sonnet-4-20250514",
      "name": "Claude Sonnet 4",
      "description": "A balanced Anthropic model.",
      "context_length": 200000,
      "pricing": {
        "prompt": "0.000003",
        "completion": "0.000015",
        "input_cache_read": "0.0000003"
      }
    }
  ]
}
""".utf8)

private func makeSnapshot(
    totalCredits: Double? = 100,
    accountTotalUsage: Double? = 25,
    usageDaily: Double = 0.5,
    byokUsageDaily: Double = 0,
    usageMonthly: Double = 10,
    keyLimit: Double? = 50,
    keyLimitRemaining: Double? = 25,
    keyLimitReset: String? = nil,
    keyExpiresAt: String? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        capturedAt: Date(timeIntervalSince1970: 0),
        keyLabel: "Test Key",
        keyLimit: keyLimit,
        keyLimitRemaining: keyLimitRemaining,
        usageAllTime: 25,
        usageDaily: usageDaily,
        usageWeekly: 4,
        usageMonthly: usageMonthly,
        byokUsageAllTime: 0,
        byokUsageDaily: byokUsageDaily,
        byokUsageWeekly: 0,
        byokUsageMonthly: 0,
        totalCredits: totalCredits,
        accountTotalUsage: accountTotalUsage,
        keyLimitReset: keyLimitReset,
        keyExpiresAt: keyExpiresAt
    )
}

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func makeSession(handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    URLProtocolMock.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolMock.self]
    return URLSession(configuration: configuration)
}

private func response(statusCode: Int, body: Data) -> (HTTPURLResponse, Data) {
    let url = URL(string: "https://example.test")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    return (response, body)
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fail(message)
    }
}

private func approximatelyEqual(_ lhs: Double?, _ rhs: Double, tolerance: Double = 0.000_001) -> Bool {
    guard let lhs else { return false }
    return abs(lhs - rhs) <= tolerance
}

private func fail(_ message: String) -> Never {
    fatalError("Check failed: \(message)")
}

private final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

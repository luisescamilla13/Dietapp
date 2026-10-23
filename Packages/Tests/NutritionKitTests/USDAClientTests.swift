import Foundation
import Synchronization
import Testing
@testable import NutritionKit

struct USDAClientTests {
    @Test func decodesFoodsFromSearchResults() async throws {
        let client = USDAClient(apiKey: "test-key", http: FakeHTTP(status: 200, body: try fixture("search-apple")))

        let foods = try await client.searchFoods(matching: "apple")

        #expect(foods.map(\.name) == ["Apple, raw", "Apples, fuji, with skin, raw", "Croissants, apple"])
        let apple = try #require(foods.first)
        #expect(apple.id == "usda:2709215")
        #expect(apple.nutrientsPer100g == Nutrients(calories: 61, protein: 0.17, carbohydrates: 14.8, fat: 0.15, fiber: 2.1))
        #expect(apple.portions.first == Portion(name: "1 small", grams: 165))
    }

    @Test func usesAtwaterEnergyWhenStandardEnergyIsMissing() async throws {
        let client = USDAClient(apiKey: "test-key", http: FakeHTTP(status: 200, body: try fixture("search-apple")))

        let fuji = try #require(try await client.searchFoods(matching: "apple").first { $0.sourceID == "1750340" })

        #expect(fuji.nutrientsPer100g.calories == 58.2)
        #expect(fuji.portions.isEmpty)
    }

    @Test func skipsFoodsWithoutEnergy() async throws {
        let body = Data(#"{"foods": [{"fdcId": 1, "description": "Water", "foodNutrients": [{"nutrientId": 1003, "value": 0}]}]}"#.utf8)
        let client = USDAClient(apiKey: "test-key", http: FakeHTTP(status: 200, body: body))

        #expect(try await client.searchFoods(matching: "water").isEmpty)
    }

    @Test(arguments: [
        (403, USDAClientError.invalidAPIKey),
        (429, USDAClientError.rateLimited),
        (500, USDAClientError.unexpectedStatus(500)),
    ])
    func mapsHTTPErrors(status: Int, expected: USDAClientError) async {
        let client = USDAClient(apiKey: "test-key", http: FakeHTTP(status: status, body: Data()))

        await #expect(throws: expected) {
            try await client.searchFoods(matching: "apple")
        }
    }

    @Test func blankQueryReturnsNoResultsWithoutARequest() async throws {
        let http = FakeHTTP(status: 200, body: try fixture("search-apple"))
        let client = USDAClient(apiKey: "test-key", http: http)

        #expect(try await client.searchFoods(matching: "   ").isEmpty)
        #expect(http.requestCount == 0)
    }

    @Test func requestSendsKeyInHeaderAndGenericDataTypes() throws {
        let request = try USDAClient(apiKey: "test-key", pageSize: 10).searchRequest(for: "apple")

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "test-key")
        #expect(request.url?.query == nil)

        let body = try JSONDecoder().decode(DecodedBody.self, from: try #require(request.httpBody))
        #expect(body == DecodedBody(query: "apple", pageSize: 10, dataType: ["Survey (FNDDS)", "Foundation", "SR Legacy"]))
    }

    /// Hits the real API. Runs only when `USDA_API_KEY` is set, so CI stays offline.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["USDA_API_KEY"] != nil))
    func liveSearchReturnsResults() async throws {
        let client = USDAClient(apiKey: try #require(ProcessInfo.processInfo.environment["USDA_API_KEY"]))

        let foods = try await client.searchFoods(matching: "apple")

        #expect(!foods.isEmpty)
        #expect(foods.allSatisfy { $0.nutrientsPer100g.calories >= 0 })
    }
}

private struct DecodedBody: Decodable, Equatable {
    var query: String
    var pageSize: Int
    var dataType: [String]
}

private final class FakeHTTP: HTTPDataLoading {
    let status: Int
    let body: Data
    private let count = Mutex(0)

    init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    var requestCount: Int { count.withLock { $0 } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        count.withLock { $0 += 1 }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

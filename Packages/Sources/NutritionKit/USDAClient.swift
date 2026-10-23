import Foundation

public enum USDAClientError: Error, Equatable {
    case invalidAPIKey
    case rateLimited
    case unexpectedStatus(Int)
}

/// Client for the USDA FoodData Central search API.
/// https://fdc.nal.usda.gov/api-guide
public struct USDAClient: NutritionSearching {
    private let apiKey: String
    private let http: any HTTPDataLoading
    private let pageSize: Int

    private static let searchURL = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!

    /// Generic foods only. Branded products crowd out generic results for queries
    /// like "apple", and are looked up by barcode instead.
    static let dataTypes = ["Survey (FNDDS)", "Foundation", "SR Legacy"]

    public init(apiKey: String, http: any HTTPDataLoading = URLSession.shared, pageSize: Int = 25) {
        self.apiKey = apiKey
        self.http = http
        self.pageSize = pageSize
    }

    public func searchFoods(matching query: String) async throws -> [Food] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let (data, response) = try await http.data(for: searchRequest(for: query))

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: break
        case 401, 403: throw USDAClientError.invalidAPIKey
        case 429: throw USDAClientError.rateLimited
        default: throw USDAClientError.unexpectedStatus(status)
        }

        return try JSONDecoder().decode(SearchResponse.self, from: data).foods.compactMap(\.food)
    }

    func searchRequest(for query: String) throws -> URLRequest {
        var request = URLRequest(url: Self.searchURL)
        request.httpMethod = "POST"
        // The key goes in a header rather than the URL so it stays out of logs.
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SearchRequestBody(query: query, pageSize: pageSize, dataType: Self.dataTypes)
        )
        return request
    }
}

// MARK: - Wire format

struct SearchRequestBody: Encodable {
    var query: String
    var pageSize: Int
    var dataType: [String]
}

private struct SearchResponse: Decodable {
    var foods: [SearchFood]
}

private struct SearchFood: Decodable {
    var fdcId: Int
    var description: String
    var foodNutrients: [FoodNutrient]
    var foodMeasures: [FoodMeasure]?

    struct FoodNutrient: Decodable {
        var nutrientId: Int?
        var value: Double?
    }

    struct FoodMeasure: Decodable {
        var disseminationText: String?
        var gramWeight: Double?
    }

    /// USDA nutrient IDs. Values in search results are per 100 g.
    private enum NutrientID {
        static let energy = 1008
        // Foundation foods report energy only through the Atwater factors.
        static let energyAtwaterSpecific = 2048
        static let energyAtwaterGeneral = 2047
        static let protein = 1003
        static let fat = 1004
        static let carbohydrates = 1005
        static let fiber = 1079
    }

    /// `nil` when the food has no energy value, since it can't be logged without one.
    var food: Food? {
        let values = Dictionary(
            foodNutrients.compactMap { nutrient in
                nutrient.nutrientId.flatMap { id in nutrient.value.map { (id, $0) } }
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard let calories = values[NutrientID.energy]
            ?? values[NutrientID.energyAtwaterSpecific]
            ?? values[NutrientID.energyAtwaterGeneral]
        else { return nil }

        // A missing macronutrient is reported as 0, which is how USDA lists foods without it.
        let nutrients = Nutrients(
            calories: calories,
            protein: values[NutrientID.protein] ?? 0,
            carbohydrates: values[NutrientID.carbohydrates] ?? 0,
            fat: values[NutrientID.fat] ?? 0,
            fiber: values[NutrientID.fiber] ?? 0
        )
        let portions = (foodMeasures ?? []).compactMap { measure -> Portion? in
            guard let name = measure.disseminationText, let grams = measure.gramWeight, grams > 0 else { return nil }
            return Portion(name: name, grams: grams)
        }
        return Food(source: .usda, sourceID: String(fdcId), name: description, nutrientsPer100g: nutrients, portions: portions)
    }
}

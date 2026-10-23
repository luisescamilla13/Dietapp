/// Searches a nutrition database for foods by name.
public protocol NutritionSearching: Sendable {
    func searchFoods(matching query: String) async throws -> [Food]
}

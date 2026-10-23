/// Where a food's data comes from.
public enum FoodSource: String, Sendable, Hashable, Codable {
    case usda
}

/// A food with its nutrients per 100 g and the common portions it is eaten in.
public struct Food: Sendable, Hashable, Codable, Identifiable {
    public var source: FoodSource
    /// The identifier of the food in its source, such as a USDA FDC ID.
    public var sourceID: String
    public var name: String
    public var nutrientsPer100g: Nutrients
    public var portions: [Portion]

    public var id: String { "\(source.rawValue):\(sourceID)" }

    public init(source: FoodSource, sourceID: String, name: String, nutrientsPer100g: Nutrients, portions: [Portion] = []) {
        self.source = source
        self.sourceID = sourceID
        self.name = name
        self.nutrientsPer100g = nutrientsPer100g
        self.portions = portions
    }

    public func nutrients(forGrams grams: Double) -> Nutrients {
        nutrientsPer100g.scaled(by: grams / 100)
    }
}

/// A household measure for a food, such as "1 medium" = 200 g.
public struct Portion: Sendable, Hashable, Codable {
    public var name: String
    public var grams: Double

    public init(name: String, grams: Double) {
        self.name = name
        self.grams = grams
    }
}

import Foundation

/// Where a food's data comes from.
public enum FoodSource: String, Sendable, Hashable, Codable {
    case usda
}

/// A food with its nutrients per 100 g and the common portions it is eaten in.
public struct Food: Sendable, Hashable, Codable, Identifiable {
    public var source: FoodSource
    /// The identifier of the food in its source, such as a USDA FDC ID.
    public var sourceID: String
    /// The name in English, as the source writes it.
    public var name: String
    /// A Spanish name, which only the most common foods have.
    public var spanishName: String?
    public var nutrientsPer100g: Nutrients
    public var portions: [Portion]

    public var id: String { "\(source.rawValue):\(sourceID)" }

    public init(source: FoodSource, sourceID: String, name: String, spanishName: String? = nil, nutrientsPer100g: Nutrients, portions: [Portion] = []) {
        self.source = source
        self.sourceID = sourceID
        self.name = name
        self.spanishName = spanishName
        self.nutrientsPer100g = nutrientsPer100g
        self.portions = portions
    }

    /// The name to show in `language`, falling back to English.
    public func name(in language: Locale.Language) -> String {
        language.isSpanish ? spanishName ?? name : name
    }

    public func nutrients(forGrams grams: Double) -> Nutrients {
        nutrientsPer100g.scaled(by: grams / 100)
    }
}

/// A household measure for a food, such as "1 medium" = 200 g.
public struct Portion: Sendable, Hashable, Codable {
    /// The name in English, which `MealMatcher` reads to find units like "cup".
    public var name: String
    public var spanishName: String?
    public var grams: Double

    public init(name: String, spanishName: String? = nil, grams: Double) {
        self.name = name
        self.spanishName = spanishName
        self.grams = grams
    }

    /// The name to show in `language`, falling back to English.
    public func name(in language: Locale.Language) -> String {
        language.isSpanish ? spanishName ?? name : name
    }
}

private extension Locale.Language {
    var isSpanish: Bool { languageCode == .spanish }
}

/// One food or drink found in a meal description.
public struct ParsedFoodItem: Sendable, Hashable {
    /// The user's own words for this item, such as "dos tacos al pastor".
    public var name: String
    public var quantity: Double
    /// The unit for `quantity` in English, such as "piece" or "cup".
    public var unit: String
    /// A generic English name to look up in a nutrition database, such as "pork taco".
    public var searchTerm: String
    /// The model's estimate for the whole quantity, used when the database has no matching portion.
    public var estimatedGrams: Double?

    public init(name: String, quantity: Double, unit: String, searchTerm: String, estimatedGrams: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.searchTerm = searchTerm
        self.estimatedGrams = estimatedGrams
    }
}

/// Whether meal descriptions can be parsed on this device right now.
public enum FoodParsingAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    /// The model is still downloading or otherwise not ready yet.
    case modelNotReady
    case unavailable
}

public enum FoodParsingError: Error, Equatable {
    case unavailable(FoodParsingAvailability)
    case unsupportedLanguage
    /// The model declined the request, for example because of its safety guardrails.
    case refused
    case failed
}

/// Turns a natural-language meal description into food items.
public protocol FoodParsing: Sendable {
    var availability: FoodParsingAvailability { get }

    /// Streams the items found so far. Each element replaces the previous one, and
    /// the last element is the complete result.
    func parse(_ description: String) -> AsyncThrowingStream<[ParsedFoodItem], any Error>
}

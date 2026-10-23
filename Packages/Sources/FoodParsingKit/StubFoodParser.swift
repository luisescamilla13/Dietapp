/// Returns fixed items, for previews, UI tests and devices without Apple Intelligence.
public struct StubFoodParser: FoodParsing {
    public var availability: FoodParsingAvailability
    public var items: [ParsedFoodItem]

    public init(availability: FoodParsingAvailability = .available, items: [ParsedFoodItem] = StubFoodParser.sampleItems) {
        self.availability = availability
        self.items = items
    }

    public func parse(_ description: String) -> AsyncThrowingStream<[ParsedFoodItem], any Error> {
        let availability = availability
        let items = items
        return AsyncThrowingStream { continuation in
            guard availability == .available else {
                continuation.finish(throwing: FoodParsingError.unavailable(availability))
                return
            }
            // Yield one more item at a time, like the model's stream.
            for count in 1...max(items.count, 1) {
                continuation.yield(Array(items.prefix(count)))
            }
            continuation.finish()
        }
    }

    public static let sampleItems = [
        ParsedFoodItem(name: "dos tacos al pastor", quantity: 2, unit: "piece", searchTerm: "pork taco", estimatedGrams: 180),
        ParsedFoodItem(name: "una coca", quantity: 1, unit: "can", searchTerm: "cola soft drink", estimatedGrams: 355),
    ]
}

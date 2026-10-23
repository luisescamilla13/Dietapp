import Testing
@testable import FoodParsingKit

struct PartialItemTests {
    @Test func needsANameToShow() {
        #expect(PartialItem(quantity: 2).parsedItem == nil)
        #expect(PartialItem(name: "  ").parsedItem == nil)
    }

    @Test func fillsMissingFieldsWithPlaceholders() {
        #expect(PartialItem(name: "manzana").parsedItem == ParsedFoodItem(name: "manzana", quantity: 1, unit: "piece", searchTerm: "manzana"))
    }

    @Test func keepsCompleteFields() {
        let item = PartialItem(name: "taco al pastor", quantity: 2, unit: "piece", searchTerm: "pork taco", gramsPerUnit: 90).parsedItem

        #expect(item == ParsedFoodItem(name: "taco al pastor", quantity: 2, unit: "piece", searchTerm: "pork taco", estimatedGrams: 180))
    }
}

struct StubFoodParserTests {
    @Test func streamsOneMoreItemAtATime() async throws {
        var snapshots: [[ParsedFoodItem]] = []
        for try await items in StubFoodParser().parse("anything") {
            snapshots.append(items)
        }

        #expect(snapshots.map(\.count) == [1, 2])
        #expect(snapshots.last == StubFoodParser.sampleItems)
    }

    @Test func throwsWhenUnavailable() async {
        let parser = StubFoodParser(availability: .appleIntelligenceNotEnabled)

        await #expect(throws: FoodParsingError.unavailable(.appleIntelligenceNotEnabled)) {
            for try await _ in parser.parse("anything") {}
        }
    }
}

struct GroundingTests {
    @Test(arguments: [
        ("dos tacos al pastor", "dos tacos al pastor y una coca"),
        ("Medio Platano", "una manzana y medio plátano"),
        ("un medio plátano", "una manzana y medio plátano"),
        ("dos ta", "dos tacos al pastor"),
    ])
    func acceptsWordsFromTheDescription(words: String, description: String) {
        #expect(Grounding.isGrounded(words, in: description))
    }

    @Test(arguments: [
        ("pork taco", "chilaquiles verdes"),
        ("quesadilla", "chilaquiles verdes"),
        ("", "chilaquiles verdes"),
    ])
    func rejectsWordsThatAreNotThere(words: String, description: String) {
        #expect(!Grounding.isGrounded(words, in: description))
    }
}

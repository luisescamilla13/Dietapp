import Foundation
import Testing
import FoodParsingKit

/// An evaluation set for the prompt: run it after changing the instructions or the
/// schema. It uses the real on-device model, so it only runs where Apple Intelligence
/// is available (a supported Mac or iPhone), not in CI.
@Suite(.enabled(if: FoundationModelsFoodParser().availability == .available))
struct FoundationModelsFoodParserTests {
    struct Case: Sendable, CustomTestStringConvertible {
        var description: String
        /// One entry per expected item: a word its search term must contain, and its quantity.
        var expected: [(searchTermContains: String, quantity: Double)]

        var testDescription: String { description }
    }

    static let cases = [
        Case(description: "dos tacos al pastor y una coca", expected: [("taco", 2), ("cola", 1)]),
        Case(description: "two scrambled eggs and a coffee with milk", expected: [("egg", 2), ("coffee", 1)]),
        Case(description: "3 tortillas de maíz con frijoles", expected: [("tortilla", 3), ("bean", 1)]),
        Case(description: "una manzana y medio plátano", expected: [("apple", 1), ("banana", 0.5)]),
        Case(description: "chilaquiles verdes", expected: [("chilaquiles", 1)]),
    ]

    let parser = FoundationModelsFoodParser()

    @Test(arguments: cases)
    func parsesItemsAndQuantities(_ testCase: Case) async throws {
        let items = try await finalItems(for: testCase.description)

        #expect(items.count == testCase.expected.count, "\(items)")
        for (word, quantity) in testCase.expected {
            let item = try #require(items.first { $0.searchTerm.localizedCaseInsensitiveContains(word) }, "No item for \(word) in \(items)")
            #expect(item.quantity == quantity, "\(item)")
            #expect((item.estimatedGrams ?? 0) > 0, "\(item)")
        }
    }

    @Test func streamsPartialResultsBeforeTheFinalOne() async throws {
        var snapshots = 0
        for try await _ in parser.parse("un plátano y un vaso de leche") {
            snapshots += 1
        }

        #expect(snapshots > 1)
    }

    private func finalItems(for description: String) async throws -> [ParsedFoodItem] {
        var last: [ParsedFoodItem] = []
        for try await items in parser.parse(description) {
            last = items
        }
        return last
    }
}

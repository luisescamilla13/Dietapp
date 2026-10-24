import Foundation
import FoundationModels

/// Parses meal descriptions with Apple's on-device language model.
public struct FoundationModelsFoodParser: FoodParsing {
    private let model: SystemLanguageModel

    public init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    public var availability: FoodParsingAvailability {
        switch model.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady): .modelNotReady
        case .unavailable: .unavailable
        }
    }

    public func parse(_ description: String) -> AsyncThrowingStream<[ParsedFoodItem], any Error> {
        let availability = availability
        let model = model
        return AsyncThrowingStream { continuation in
            guard availability == .available else {
                continuation.finish(throwing: FoodParsingError.unavailable(availability))
                return
            }
            let task = Task {
                do {
                    let session = LanguageModelSession(model: model, instructions: Self.instructions)
                    let stream = session.streamResponse(
                        to: description,
                        generating: GeneratedMeal.self,
                        // Greedy sampling gives the same answer for the same description.
                        options: GenerationOptions(samplingMode: .greedy)
                    )
                    for try await snapshot in stream {
                        continuation.yield(Self.items(from: snapshot.content, in: description))
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.parsingError(for: error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static let instructions = """
        You turn a person's description of what they ate or drank into a list of foods. \
        The description can be in Spanish or English.

        Rules:
        - Make one item per distinct food or drink. A prepared dish such as "chilaquiles" \
        or "taco al pastor" is one item, not its ingredients. A drink with an add-in, \
        such as "café con leche", is one item.
        - First copy the words for the item exactly as the person wrote them, in their language. \
        If they wrote in Spanish, the copied words are in Spanish. Then read the quantity from those words: \
        "two" or "dos" is 2, "3" is 3, "half" or "medio" is 0.5. Use 1 only when no amount is said.
        - Write the search term as the food's generic name in English, without brands: \
        "coca" is "cola soft drink" and "taco al pastor" is "pork taco". A dish that is also \
        called by its own name in English keeps that name: "chilaquiles verdes" is "chilaquiles".
        - Estimate the grams of one unit, for example one corn tortilla weighs about 30 g \
        and one cup of coffee about 240 g.
        - Never add foods the person didn't mention.
        """

    private static func items(from meal: GeneratedMeal.PartiallyGenerated, in description: String) -> [ParsedFoodItem] {
        (meal.items ?? []).compactMap { item in
            // The model sometimes adds foods from the instructions' examples. Each item
            // copies its words from the description, so drop items whose words aren't there.
            guard let words = item.words, Grounding.isGrounded(words, in: description) else { return nil }
            return PartialItem(
                name: item.words,
                quantity: item.quantity,
                unit: item.unit,
                searchTerm: item.searchTerm,
                gramsPerUnit: item.gramsPerUnit
            ).parsedItem
        }
    }

    private static func parsingError(for error: LanguageModelSession.GenerationError) -> FoodParsingError {
        switch error {
        case .unsupportedLanguageOrLocale: .unsupportedLanguage
        case .guardrailViolation, .refusal: .refused
        case .assetsUnavailable: .unavailable(.modelNotReady)
        default: .failed
        }
    }
}

// MARK: - Generation schema

@Generable
struct GeneratedMeal {
    @Guide(description: "One entry per distinct food or drink mentioned")
    var items: [GeneratedItem]
}

// Properties are generated in declaration order, so the order is part of the prompt:
// copying the words first lets the model read the quantity from them.
@Generable
struct GeneratedItem {
    @Guide(description: "The words for this item copied from the description in its original language, never translated")
    var words: String

    @Guide(description: "The amount in those words as a number; 1 if no amount is said", .range(0.1...100))
    var quantity: Double

    @Guide(description: "The unit in English, such as piece, cup, bowl, slice, can, glass, gram or tablespoon")
    var unit: String

    @Guide(description: "The food's generic name in English, without brands, such as 'pork taco', 'cola soft drink', 'coffee with milk' or 'corn tortilla'")
    var searchTerm: String

    @Guide(description: "Estimated grams of one unit", .range(1...2000))
    var gramsPerUnit: Double
}

/// A streamed item before it is complete. Fields fill in as the model writes them.
struct PartialItem: Equatable {
    var name: String?
    var quantity: Double?
    var unit: String?
    var searchTerm: String?
    var gramsPerUnit: Double?

    /// `nil` until there is a name to show. Missing fields get placeholders that the
    /// next snapshot replaces.
    var parsedItem: ParsedFoodItem? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        let searchTerm = searchTerm?.trimmingCharacters(in: .whitespaces)
        let quantity = quantity ?? 1
        return ParsedFoodItem(
            name: name,
            quantity: quantity,
            unit: unit ?? "piece",
            searchTerm: searchTerm.flatMap { $0.isEmpty ? nil : $0 } ?? name,
            estimatedGrams: gramsPerUnit.map { $0 * quantity }
        )
    }
}

/// Checks that text the model claims to have copied really comes from the user's description.
enum Grounding {
    /// True when at least half of the words appear in the description, ignoring case and
    /// accents. A word may be a prefix, since streamed words can be cut off mid-way.
    static func isGrounded(_ words: String, in description: String) -> Bool {
        let wordTokens = tokens(words)
        guard !wordTokens.isEmpty else { return false }
        let descriptionTokens = tokens(description)
        let found = wordTokens.filter { token in descriptionTokens.contains { $0.hasPrefix(token) } }
        return found.count * 2 >= wordTokens.count
    }

    private static func tokens(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

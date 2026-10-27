import Foundation
import Testing

/// The app ships in English and Spanish, so every string needs a Spanish translation.
/// Xcode adds new strings to the catalogs while building, untranslated, and these
/// tests catch them.
struct LocalizationTests {
    @Test(arguments: ["Localizable", "InfoPlist"])
    func everyStringHasASpanishTranslation(catalog: String) throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../Dietapp/\(catalog).xcstrings")
        let strings = try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: url)).strings

        let untranslated = strings.filter { _, string in
            string.localizations?["es"]?.stringUnit.state != "translated"
        }
        #expect(!strings.isEmpty)
        #expect(untranslated.isEmpty, "\(untranslated.keys.sorted())")
    }

    @Test func spanishIsBundled() throws {
        let path = try #require(Bundle.main.path(forResource: "es", ofType: "lproj"))
        let spanish = try #require(Bundle(path: path))

        #expect(spanish.localizedString(forKey: "Today", value: nil, table: nil) == "Hoy")
    }
}

private struct StringCatalog: Decodable {
    struct Entry: Decodable {
        var localizations: [String: Localization]?
    }

    struct Localization: Decodable {
        var stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        var state: String
    }

    var strings: [String: Entry]
}

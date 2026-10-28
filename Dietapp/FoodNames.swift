import Foundation
import NutritionKit

extension Locale.Language {
    /// The language the app's interface is shown in, which food names follow.
    static var app: Locale.Language {
        Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }
}

extension Food {
    var displayName: String { name(in: .app) }
}

extension Portion {
    var displayName: String { name(in: .app) }
}

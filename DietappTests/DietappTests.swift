import Foundation
import Testing
@testable import Dietapp

struct AppConfigurationTests {
    @Test func usdaAPIKeyIsInjectedFromXcconfig() throws {
        let raw = try #require(Bundle.main.object(forInfoDictionaryKey: "USDAAPIKey") as? String)

        // An unexpanded "$(USDA_API_KEY)" means Base.xcconfig is not attached to the target.
        #expect(!raw.isEmpty)
        #expect(!raw.contains("$("))
        #expect(AppConfiguration.usdaAPIKey == raw)
    }
}

import Foundation

/// Values injected at build time from Config/*.xcconfig through Info.plist.
nonisolated enum AppConfiguration {
    static var usdaAPIKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "USDAAPIKey") as? String ?? ""
        return key.isEmpty ? "DEMO_KEY" : key
    }
}

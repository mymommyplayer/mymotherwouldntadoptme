import Foundation

var lastFMAPIKey: String {
    if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "LASTFM_API_KEY") as? String,
       !bundleKey.isEmpty {
        return bundleKey
    }
    return SecretsLoader.value(for: "LASTFM_API_KEY", fallback: "")
}

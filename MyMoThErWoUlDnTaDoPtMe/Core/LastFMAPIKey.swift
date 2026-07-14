import Foundation

var lastFMAPIKey: String {
    if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "LASTFM_API_KEY") as? String,
       !bundleKey.isEmpty, bundleKey != "$(LASTFM_API_KEY)" {
        return bundleKey
    }
    let fromConfig = SecretsLoader.value(for: "LASTFM_API_KEY", fallback: "")
    if !fromConfig.isEmpty { return fromConfig }
    return "cce5b79bbdcbfaa350e727cd39abc1a5"
}

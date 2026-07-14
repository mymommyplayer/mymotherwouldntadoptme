import Foundation

var soundCloudClientID: String {
    if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "SOUNDCLOUD_CLIENT_ID") as? String,
       !bundleKey.isEmpty, bundleKey != "$(SOUNDCLOUD_CLIENT_ID)" {
        return bundleKey
    }
    let fromConfig = SecretsLoader.value(for: "SOUNDCLOUD_CLIENT_ID", fallback: "")
    if !fromConfig.isEmpty { return fromConfig }
    return "lmRjTI0FqeXygHMXc3hRzS7hth20PNk5"
}

import Foundation

var soundCloudClientID: String {
    if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "SOUNDCLOUD_CLIENT_ID") as? String,
       !bundleKey.isEmpty {
        return bundleKey
    }
    return SecretsLoader.value(for: "SOUNDCLOUD_CLIENT_ID", fallback: "")
}

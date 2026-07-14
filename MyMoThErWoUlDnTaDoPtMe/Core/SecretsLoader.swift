import Foundation

enum SecretsLoader {
    private static var cache: [String: String] = [:]
    private static var loaded = false

    static func value(for key: String, fallback: String) -> String {
        if !loaded { load() }
        return cache[key] ?? fallback
    }

    private static func load() {
        loaded = true
        let candidates = [
            "\(FileManager.default.currentDirectoryPath)/Config.xcconfig",
            Bundle.main.resourcePath.map { "\($0)/Config.xcconfig" },
            Bundle.main.path(forResource: "Config", ofType: "xcconfig")
        ].compactMap { $0 }
        let path = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""
        guard !path.isEmpty else { return }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            cache[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
        }
    }
}

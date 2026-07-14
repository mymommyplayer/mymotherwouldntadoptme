import Foundation

private actor SecretsLoaderActor {
    private var cache: [String: String] = [:]
    private var loaded = false

    private let configPath: String = {
        let candidates = [
            "\(FileManager.default.currentDirectoryPath)/Config.xcconfig",
            Bundle.main.resourcePath.map { "\($0)/Config.xcconfig" },
            Bundle.main.path(forResource: "Config", ofType: "xcconfig")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }()

    func value(for key: String, fallback: String) -> String {
        if !loaded { load() }
        return cache[key] ?? fallback
    }

    private func load() {
        loaded = true
        guard !configPath.isEmpty else { return }
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            cache[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
        }
    }
}

enum SecretsLoader {
    private static let actor = SecretsLoaderActor()

    static func value(for key: String, fallback: String) -> String {
        var result: String = fallback
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await actor.value(for: key, fallback: fallback)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}

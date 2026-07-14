import Foundation

enum YTDLPError: LocalizedError {
    case notInstalled
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "yt-dlp not found. Install: brew install yt-dlp"
        case .extractionFailed(let msg): "Stream extraction failed: \(msg)"
        }
    }
}

// MARK: - yt-dlp search JSON model

struct YTDLPSearchItem: Decodable {
    let id: String
    let title: String
    let channel: String?
    let uploader: String?
    let duration: Double?
    let thumbnails: [YTDLPThumbnail]?
    let url: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        title = try container.decode(String.self, forKey: .title)
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        uploader = try container.decodeIfPresent(String.self, forKey: .uploader)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        thumbnails = try container.decodeIfPresent([YTDLPThumbnail].self, forKey: .thumbnails)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, channel, uploader, duration, thumbnails, url
    }
}

struct YTDLPThumbnail: Decodable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - yt-dlp wrapper

struct YTDLP {
    private static let queue = DispatchQueue(
        label: "com.mymother.yt-dlp",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private static let processTimeout: TimeInterval = 20
    private static let searchTimeout: TimeInterval = 20

    private static var cachedPath: String?
    private static let pathCandidates = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/usr/bin/yt-dlp"
    ]

    private static var executable: String {
        if let cachedPath { return cachedPath }
        for path in pathCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedPath = path
                return path
            }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "which yt-dlp"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            cachedPath = path
            return path
        }
        return "/opt/homebrew/bin/yt-dlp"
    }

    private static let cache = NSCache<NSString, NSArray>()

    static func extractStreamURL(videoID: String) async throws -> URL {
        try await extract(url: "https://www.youtube.com/watch?v=\(videoID)")
    }

    static func extractStreamURL(webpageURL: String) async throws -> URL {
        try await extract(url: webpageURL)
    }

    static func ytSearch(query: String, limit: Int = 20) async throws -> [SearchResult] {
        try await runSearch(prefix: "ytsearch", query: query, limit: limit, source: .youtube)
    }

    static func scSearch(query: String, limit: Int = 20) async throws -> [SearchResult] {
        try await runSearch(prefix: "scsearch", query: query, limit: limit, source: .soundcloud)
    }

    private static func runSearch(prefix: String, query: String, limit: Int, source: SearchResult.SourceType) async throws -> [SearchResult] {
        let cacheKey = "\(prefix):\(query)" as NSString
        if let cached = cache.object(forKey: cacheKey) as? [SearchResult] {
            return cached
        }

        let searchQuery = "\(prefix)\(limit):\(query)"
        let output = try await runRaw(args: ["-j", "--flat-playlist", "--ignore-errors", searchQuery], timeout: searchTimeout)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        var results: [SearchResult] = []
        for line in lines {
            guard let item = try? decoder.decode(YTDLPSearchItem.self, from: Data(line.utf8)),
                  !item.id.isEmpty else { continue }
            let artist = item.channel ?? item.uploader ?? "Unknown"
            let thumb = item.thumbnails?.first.flatMap { URL(string: $0.url) }
            let webpageURL = item.url.flatMap { URL(string: $0) }
            results.append(SearchResult(
                id: item.id,
                title: item.title,
                artist: artist,
                duration: item.duration ?? 0,
                source: source,
                thumbnailURL: thumb,
                streamURL: nil,
                webpageURL: webpageURL
            ))
        }

        if !results.isEmpty {
            cache.setObject(results as NSArray, forKey: cacheKey)
        }
        return results
    }

    private static func extract(url: String) async throws -> URL {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = ["-f", "bestaudio[ext=m4a]/bestaudio", "-g", url]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()

        return try await withTaskCancellationHandler(
            handler: { task.terminate() },
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    queue.async {
                        let timedOut = waitWithTimeout(task, timeout: processTimeout)
                        if timedOut {
                            continuation.resume(throwing: YTDLPError.extractionFailed("Timeout after \(Int(processTimeout))s"))
                            return
                        }
                        guard task.terminationStatus == 0 else {
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                            let msg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: YTDLPError.extractionFailed(msg))
                            return
                        }
                        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let urlString = String(data: data, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        guard !urlString.isEmpty, let streamURL = URL(string: urlString) else {
                            continuation.resume(throwing: YTDLPError.extractionFailed("No URL in output"))
                            return
                        }
                        continuation.resume(returning: streamURL)
                    }
                }
            }
        )
    }

    private static func runRaw(args: [String], timeout: TimeInterval? = nil) async throws -> String {
        let t = timeout ?? processTimeout
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()

        return try await withTaskCancellationHandler(
            handler: { task.terminate() },
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    queue.async {
                        let timedOut = waitWithTimeout(task, timeout: t)
                        if timedOut {
                            continuation.resume(throwing: YTDLPError.extractionFailed("Timeout after \(Int(t))s"))
                            return
                        }
                        guard task.terminationStatus == 0 else {
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                            let msg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: YTDLPError.extractionFailed(msg))
                            return
                        }
                        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                    }
                }
            }
        )
    }

    private static func waitWithTimeout(_ task: Process, timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var timedOut = false
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            timedOut = true
            task.terminate()
            semaphore.signal()
        }
        task.terminationHandler = { _ in
            timer.cancel()
            semaphore.signal()
        }
        timer.activate()
        semaphore.wait()
        return timedOut
    }
}

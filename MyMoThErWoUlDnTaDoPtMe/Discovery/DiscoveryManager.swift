import Foundation
import OSLog

extension Notification.Name {
    static let discoveryError = Notification.Name("discoveryError")
}

private let log = Logger(subsystem: "com.MyMoThErWoUlDnTaDoPtMe", category: "Discovery")

@MainActor
class DiscoveryManager: ObservableObject {
    @Published private(set) var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: SettingsKeys.discoveryModeEnabled) }
    }
    @Published var variety: Double {
        didSet { UserDefaults.standard.set(variety, forKey: SettingsKeys.discoveryVariety) }
    }
    @Published private(set) var isSearching = false
    @Published private(set) var lastError: String?

    private let lastFM: LastFMService
    private let queueManager: QueueManager
    private var searchTrack: ((String) async throws -> [SearchResult])?
    private var resolveStream: ((SearchResult) async throws -> URL)?
    private var discoveryTask: Task<Void, Never>?
    private var searchGeneration = 0
    private var discoveredTrackIds: Set<String> = []
    var onPlayTrack: ((SearchResult) -> Void)?
    var currentTrackProvider: (() -> SearchResult?)?

    init(
        lastFM: LastFMService = LastFMService(),
        queueManager: QueueManager,
        searchTrack: ((String) async throws -> [SearchResult])? = nil,
        resolveStream: ((SearchResult) async throws -> URL)? = nil
    ) {
        self.lastFM = lastFM
        self.queueManager = queueManager
        self.searchTrack = searchTrack
        self.resolveStream = resolveStream
        self.isEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.discoveryOnStartup)
            ? true
            : UserDefaults.standard.bool(forKey: SettingsKeys.discoveryModeEnabled)
        self.variety = UserDefaults.standard.double(forKey: SettingsKeys.discoveryVariety)
        if variety == 0 { variety = 50.0 }
    }

    func configureSearch(_ handler: @escaping (String) async throws -> [SearchResult]) {
        searchTrack = handler
    }

    func configureResolve(_ handler: @escaping (SearchResult) async throws -> URL) {
        resolveStream = handler
    }

    func toggle() {
        if isEnabled {
            stop()
        } else {
            start()
        }
    }

    private func stop() {
        isEnabled = false
        discoveryTask?.cancel()
        discoveryTask = nil
        lastError = nil
        searchGeneration += 1
        discoveredTrackIds.removeAll()
    }

    private func start() {
        guard !isEnabled else { return }
        isEnabled = true
        lastError = nil
        searchGeneration += 1
        if let current = currentTrackProvider?() {
            trackDidStart(current)
        }
    }

    func trackDidStart(_ track: SearchResult) {
        guard isEnabled else { log.debug("disabled"); return }
        guard searchTrack != nil, resolveStream != nil else { log.debug("handlers not configured"); return }
        guard !discoveredTrackIds.contains(track.id) else {
            log.debug("already discovered for '\(track.title)'")
            return
        }
        discoveredTrackIds.insert(track.id)
        log.info("trackDidStart: '\(track.title)' — discovering next")

        let gen = searchGeneration
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            guard searchGeneration == gen else { return }
            await triggerDiscovery(for: track)
        }
    }

    func forceDiscovery(for track: SearchResult) {
        guard isEnabled else { setError("Discovery disabled"); return }
        discoveredTrackIds.insert(track.id)
        let gen = searchGeneration
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            guard searchGeneration == gen else { return }
            await triggerDiscovery(for: track)
        }
    }

    func trackDidFinish(_ track: SearchResult) {
        guard isEnabled else { log.debug("disabled"); return }
        guard searchTrack != nil, resolveStream != nil else { log.debug("handlers not configured"); return }

        let gen = searchGeneration
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            guard searchGeneration == gen else { return }
            await triggerDiscovery(for: track)
        }
    }

    private func triggerDiscovery(for track: SearchResult) async {
        guard let searchTrack, let resolveStream else {
            log.debug("handlers not configured")
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            var candidate: SimilarTrackInfo?

            // Strategy 1: track.getSimilar
            log.info("strategy 1: track.getSimilar for '\(track.artist)' - '\(track.title)'")
            if let similar = try? await lastFM.getSimilar(artist: track.artist, track: track.title),
               !similar.isEmpty {
                guard !Task.isCancelled else { return }
                log.info("got \(similar.count) similar tracks from Last.fm")

                let filtered = similar.filter {
                    $0.name.lowercased() != track.title.lowercased()
                        && $0.artist.name.lowercased() != track.artist.lowercased()
                }

                if !filtered.isEmpty {
                    candidate = weightedPick(from: filtered)
                    log.info("picked '\(candidate?.name ?? "?")' by \(candidate?.artist.name ?? "?")")
                }
            } else {
                log.info("strategy 1 failed or empty, trying strategy 2")
            }

            // Strategy 2: artist.getSimilar → artist.getTopTracks (fallback)
            if candidate == nil {
                log.info("strategy 2: artist.getSimilar for '\(track.artist)'")
                if let similarArtists = try? await lastFM.getSimilarArtists(artist: track.artist),
                   !similarArtists.isEmpty {
                    guard !Task.isCancelled else { return }
                    log.info("got \(similarArtists.count) similar artists")

                    if let pickedArtist = similarArtists.first {
                        log.info("picked artist '\(pickedArtist.name)'")

                        if let topTracks = try? await lastFM.getTopTracks(artist: pickedArtist.name),
                           let topTrack = topTracks.randomElement() {
                            guard !Task.isCancelled else { return }
                            log.info("got \(topTracks.count) top tracks, picked '\(topTrack.name)'")
                            candidate = SimilarTrackInfo(name: topTrack.name, artist: SimilarArtist(name: topTrack.artist.name), url: "", match: nil)
                        }
                    }
                } else {
                    log.info("strategy 2 also failed for '\(track.artist)'")
                }
            }

            guard let finalCandidate = candidate else {
                log.warning("no candidate found after all strategies for '\(track.title)'")
                return
            }

            let query = "\(finalCandidate.artist.name) \(finalCandidate.name)"
            log.info("searching '\(query)'...")

            let results: [SearchResult]
            do {
                results = try await searchTrack(query)
            } catch {
                log.warning("search failed for '\(query)': \(error.localizedDescription)")
                return
            }

            guard !Task.isCancelled else { log.debug("cancelled after search"); return }

            guard !results.isEmpty else {
                log.warning("search returned no results for '\(query)'")
                return
            }

            var resolved: SearchResult?
            var streamURL: URL?

            for candidate in results.prefix(3) {
                guard !Task.isCancelled else { return }
                if let url = try? await resolveStream(candidate) {
                    resolved = candidate
                    streamURL = url
                    break
                } else {
                    log.warning("failed to resolve '\(candidate.title)'")
                }
            }

            guard let resolved, let url = streamURL else {
                log.warning("all resolve attempts failed for '\(query)'")
                return
            }

            log.info("stream resolved for '\(resolved.title)'")

            let trackWithURL = SearchResult(
                id: resolved.id,
                title: resolved.title,
                artist: resolved.artist,
                duration: resolved.duration,
                source: resolved.source,
                thumbnailURL: resolved.thumbnailURL,
                streamURL: url
            )

            let currentTrackID = queueManager.currentItem?.track.id
            let isDuplicate = queueManager.items.contains(where: { $0.track.id == trackWithURL.id })
                || (currentTrackID == trackWithURL.id)
            guard !isDuplicate else {
                log.info("skipping duplicate '\(trackWithURL.title)' (already in queue)")
                return
            }

            var item = QueueItem(id: UUID().uuidString, track: trackWithURL, source: trackWithURL.source.rawValue)
            item.isDiscovered = true
            queueManager.add(item)
            log.info("added to queue (now \(self.queueManager.items.count) items)")

            if queueManager.currentIndex == nil {
                if let idx = queueManager.items.firstIndex(where: { $0.id == item.id }) {
                    queueManager.setCurrent(index: idx)
                    onPlayTrack?(trackWithURL)
                    log.info("auto-playing discovered track")
                }
            }

            lastError = nil

        } catch is CancellationError {
            log.debug("cancelled")
        } catch let error as YTDLPError {
            log.error("yt-dlp error: \(error.localizedDescription)")
            setError(error.localizedDescription)
        } catch let error as AppError {
            log.error("app error: \(error.localizedDescription)")
            setError(error.localizedDescription)
        } catch {
            log.error("unexpected error: \(error.localizedDescription)")
            setError(error.localizedDescription)
        }
    }

    private func setError(_ msg: String) {
        lastError = msg
        NotificationCenter.default.post(name: .discoveryError, object: nil)
    }

    private func weightedPick(from tracks: [SimilarTrackInfo]) -> SimilarTrackInfo {
        let varietyFraction = variety / 100.0
        let windowSize = max(1, Int(varietyFraction * Double(tracks.count)))
        let window = Array(tracks.prefix(windowSize))

        let weights = window.map { track -> Double in
            if let matchStr = track.match, let match = Double(matchStr) {
                return match
            }
            return 1.0
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return window.randomElement() ?? tracks[0] }

        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return window[i] }
        }
        return window.last ?? tracks[0]
    }
}

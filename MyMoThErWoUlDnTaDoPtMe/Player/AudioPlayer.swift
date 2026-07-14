import AVFoundation
import Combine

@MainActor
class AudioPlayer: ObservableObject, AudioPlayerProtocol {
    @Published private(set) var state: PlayerState = .stopped
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    var onTrackEnd: ((SearchResult) -> Void)?
    var onDiscoveryTrigger: ((SearchResult) -> Void)?

    private var primaryPlayer: AVPlayer?
    private var secondaryPlayer: AVPlayer?
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private(set) var currentTrack: SearchResult?
    private var isCrossfading = false
    private var didReportEnd = false
    private var discoveryTriggeredAt: Double = -1
    private var generation = 0
    private var crossfadeTimer: Timer?

    private var crossfadeEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.crossfadeEnabled)
    }

    private var crossfadeDuration: TimeInterval {
        max(0.5, UserDefaults.standard.double(forKey: SettingsKeys.crossfadeDuration))
    }

    func setVolume(_ volume: Float) {
        primaryPlayer?.volume = volume
        secondaryPlayer?.volume = volume
    }

    func play(url: URL, track: SearchResult? = nil) {
        if crossfadeEnabled, state == .playing, primaryPlayer != nil {
            crossfadeTo(url: url, track: track)
            return
        }
        startPlayback(url: url, track: track)
    }

    private func startPlayback(url: URL, track: SearchResult? = nil) {
        cleanup()
        generation &+= 1
        let gen = generation
        currentTrack = track

        let playerItem = AVPlayerItem(url: url)
        primaryPlayer = AVPlayer(playerItem: playerItem)
        primaryPlayer?.play()
        state = .loading

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self, let track = self.currentTrack else { return }
            onTrackEnd?(track)
        }

        durationObserver = playerItem.observe(\.status) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                do {
                    let dur = try await item.asset.load(.duration)
                    let avDur = dur.seconds
                    if let track = self.currentTrack, track.duration > 0, avDur > track.duration * 1.5 {
                        self.duration = track.duration
                    } else {
                        self.duration = avDur
                    }
                } catch {
                    self.duration = self.currentTrack?.duration ?? 0
                }
                self.state = .playing
            }
        }

        timeObserver = primaryPlayer?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if !didReportEnd, self.duration > 0, time.seconds >= self.duration - 0.3, self.state == .playing {
                didReportEnd = true
                if let track = self.currentTrack {
                    self.onTrackEnd?(track)
                }
            }
            if discoveryTriggeredAt < 0, self.duration > 0, time.seconds >= 0.5 {
                discoveryTriggeredAt = time.seconds
                if let track = self.currentTrack {
                    self.onDiscoveryTrigger?(track)
                }
            }
        }
    }

    private func crossfadeTo(url: URL, track: SearchResult? = nil) {
        guard let oldPlayer = primaryPlayer else {
            startPlayback(url: url, track: track)
            return
        }
        isCrossfading = true
        generation &+= 1
        let gen = generation
        let fadeDur = crossfadeDuration

        let newItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: newItem)
        newPlayer.volume = 0
        newPlayer.play()

        let oldVolume = oldPlayer.volume

        if let oldObs = timeObserver {
            oldPlayer.removeTimeObserver(oldObs)
            timeObserver = nil
        }
        primaryPlayer = newPlayer
        secondaryPlayer = newPlayer
        currentTrack = track

        let startTime = CACurrentMediaTime()
        let interval = 1.0 / 60.0
        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1, elapsed / fadeDur)
            oldPlayer.volume = oldVolume * Float(1 - progress)
            newPlayer.volume = Float(progress)

            if progress >= 1 {
                t.invalidate()
                completeCrossfade(gen: gen, oldPlayer: oldPlayer, newPlayer: newPlayer, newItem: newItem)
            }
        }
        RunLoop.main.add(crossfadeTimer!, forMode: .common)
    }

    private func completeCrossfade(gen: Int, oldPlayer: AVPlayer, newPlayer: AVPlayer, newItem: AVPlayerItem) {
        guard gen == generation else { return }
        endObserver.map { NotificationCenter.default.removeObserver($0) }
        endObserver = nil
        durationObserver?.invalidate()

        oldPlayer.replaceCurrentItem(with: nil)
        secondaryPlayer = nil
        isCrossfading = false
        didReportEnd = false
        discoveryTriggeredAt = -1
        state = .playing

        durationObserver = newItem.observe(\.status) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                do {
                    let dur = try await item.asset.load(.duration)
                    let avDur = dur.seconds
                    if let track = self.currentTrack, track.duration > 0, avDur > track.duration * 1.5 {
                        self.duration = track.duration
                    } else {
                        self.duration = avDur
                    }
                } catch {
                    self.duration = self.currentTrack?.duration ?? 0
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newItem,
            queue: .main
        ) { [weak self] _ in
            guard let self, let track = self.currentTrack else { return }
            onTrackEnd?(track)
        }

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if !didReportEnd, self.duration > 0, time.seconds >= self.duration - 0.3, self.state == .playing {
                didReportEnd = true
                if let track = self.currentTrack {
                    self.onTrackEnd?(track)
                }
            }
            if discoveryTriggeredAt < 0, self.duration > 0, time.seconds >= 0.5 {
                discoveryTriggeredAt = time.seconds
                if let track = self.currentTrack {
                    self.onDiscoveryTrigger?(track)
                }
            }
        }
    }

    private func cleanup() {
        guard !isCrossfading else { return }
        generation &+= 1
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        durationObserver?.invalidate()
        durationObserver = nil
        if let observer = timeObserver {
            primaryPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        primaryPlayer?.replaceCurrentItem(with: nil)
        primaryPlayer = nil
        secondaryPlayer?.replaceCurrentItem(with: nil)
        secondaryPlayer = nil
        didReportEnd = false
        discoveryTriggeredAt = -1
        currentTrack = nil
        duration = 0
        currentTime = 0
    }

    func stop() {
        cleanup()
        state = .stopped
    }

    func toggle() {
        switch state {
        case .playing:
            primaryPlayer?.pause()
            state = .paused
        case .paused:
            primaryPlayer?.play()
            state = .playing
        default:
            break
        }
    }

    func seek(to time: TimeInterval) {
        primaryPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
}

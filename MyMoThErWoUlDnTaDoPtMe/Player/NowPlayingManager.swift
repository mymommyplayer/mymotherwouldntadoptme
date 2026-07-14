import Foundation
import AppKit
import MediaPlayer

@MainActor
class NowPlayingManager: ObservableObject {
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var infoCenter = MPNowPlayingInfoCenter.default()
    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onNext: (() -> Void)?
    private var onPrevious: (() -> Void)?
    private var onSeek: ((TimeInterval) -> Void)?
    private var currentTrackID: String?

    func setup(
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        next: @escaping () -> Void,
        previous: @escaping () -> Void,
        seek: @escaping (TimeInterval) -> Void
    ) {
        onPlay = play
        onPause = pause
        onNext = next
        onPrevious = previous
        onSeek = seek

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPrevious?()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onSeek?(event.positionTime)
            return .success
        }
    }

    func updateNowPlaying(track: SearchResult, duration: TimeInterval, currentTime: TimeInterval, rate: Float, artwork: NSImage? = nil) {
        currentTrackID = track.id

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let image = artwork {
            let artworkObj = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artworkObj
        }

        infoCenter.nowPlayingInfo = info
    }

    func clear() {
        currentTrackID = nil
        infoCenter.nowPlayingInfo = nil
    }

    func isCurrentTrack(_ id: String) -> Bool {
        currentTrackID == id
    }
}

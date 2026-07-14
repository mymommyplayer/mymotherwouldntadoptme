import SwiftUI
import AVKit

enum BackgroundContent: Equatable {
    case `default`
    case image(NSImage)
    case video(AVPlayer)
    case animatedImage(URL, AVPlayer)

    var id: String {
        switch self {
        case .default: return "default"
        case .image(let img): return "image-\(img.hash)"
        case .video(let player): return "video-\(player.hash)"
        case .animatedImage(let url, _): return "gif-\(url.absoluteString)"
        }
    }

    static func == (lhs: BackgroundContent, rhs: BackgroundContent) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class BackgroundManager: ObservableObject {
    @Published var background: BackgroundContent = .default
    private var playerLoopers: [AVPlayerLooper] = []

    init() {
        setDefaultVideo()
    }

    func setDefaultVideo() {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "3LF5bEk", withExtension: "mp4"),
            Bundle.main.url(forResource: "3LF5bEk", withExtension: "mp4", subdirectory: "Resources"),
            URL(fileURLWithPath: "/Users/newuser/Documents/!main/проекты/musicplayer/Код/MyMoThErWoUlDnTaDoPtMe/Resources/3LF5bEk.mp4"),
        ]

        if let url = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            setVideo(url)
        }
    }

    func setForPlaylist(_ playlist: PlaylistEntity) {
        guard let path = playlist.backgroundPath, !path.isEmpty else {
            clear()
            return
        }
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "webp":
            setImage(url)
        case "mp4", "mov", "m4v":
            setVideo(url)
        case "gif":
            setAnimatedImage(url)
        default:
            clear()
        }
    }

    func setImage(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        playerLoopers.removeAll()
        background = .image(image)
    }

    func setVideo(_ url: URL) {
        let player = makeLoopedPlayer(url: url)
        background = .video(player)
        player.play()
    }

    func setAnimatedImage(_ url: URL) {
        let player = makeLoopedPlayer(url: url)
        background = .animatedImage(url, player)
        player.play()
    }

    func clear() {
        playerLoopers.removeAll()
        background = .default
    }

    func pause() {
        switch background {
        case .video(let player):
            player.pause()
        case .animatedImage(_, let player):
            player.pause()
        default:
            break
        }
    }

    func resume() {
        switch background {
        case .video(let player):
            player.play()
        case .animatedImage(_, let player):
            player.play()
        default:
            break
        }
    }

    private func makeLoopedPlayer(url: URL) -> AVQueuePlayer {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: playerItem)
        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        playerLoopers.removeAll()
        playerLoopers.append(looper)
        return player
    }
}

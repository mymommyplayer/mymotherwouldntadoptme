import SwiftUI
import AVKit

final class PlayerContainerView: NSView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        self.playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        wantsLayer = true
        self.playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, playerLayer.superlayer == nil {
            layer?.addSublayer(playerLayer)
        }
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

struct VideoBackgroundView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        PlayerContainerView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PlayerContainerView)?.playerLayer.player = player
    }
}

struct GIFBackgroundView: NSViewRepresentable {
    let url: URL
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        PlayerContainerView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}

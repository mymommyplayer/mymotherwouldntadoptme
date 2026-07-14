import SwiftUI
import AVKit

struct BackgroundContainer: View {
    let content: BackgroundContent

    var body: some View {
        Group {
            switch content {
            case .default:
                defaultBackground
            case .image(let image):
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            case .video(let player):
                VideoBackgroundView(player: player)
                    .ignoresSafeArea()
            case .animatedImage(let url, let player):
                GIFBackgroundView(url: url, player: player)
                    .ignoresSafeArea()
            }
        }
        .id(content.id)
    }

    private var defaultBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(white: 0.15),
                Color.black
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

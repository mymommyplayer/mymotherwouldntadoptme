import SwiftUI

struct ArtworkView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    case .failure:
                        fallback
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        fallback
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        Image(systemName: "music.note")
            .font(.system(size: size * 0.4))
            .foregroundColor(.glassForegroundTertiary)
            .frame(width: size, height: size)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
    }
}

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppFont.largeIcon)
                .foregroundColor(.glassForegroundTertiary)
            Text(title)
                .font(AppFont.body)
                .foregroundColor(.glassForegroundSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundColor(.glassForegroundTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

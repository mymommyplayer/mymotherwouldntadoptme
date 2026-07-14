import SwiftUI

struct TopCapsuleView: View {
    var body: some View {
        HStack {
            Text("MyMoThErWoUlDnTaDoPtMe")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.glassForegroundTertiary)

            Spacer()
        }
        .padding(.horizontal, Spacing.wide)
        .padding(.vertical, 6)
        .clipShape(RoundedRectangle(cornerRadius: Radius.capsule))
    }
}

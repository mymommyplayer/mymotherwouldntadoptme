import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .onSubmit(onCommit)
            .focused(isFocused)
    }
}

import SwiftUI

struct AddressBarView: View {
    @Binding var text: String
    let isLoading: Bool
    let onCommit: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isLoading { ProgressView().controlSize(.small) }
            TextField("Enter URL or file path…", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onCommit(text) }
        }
        .frame(minWidth: 300, idealWidth: 480, maxWidth: 600)
    }
}

import SwiftUI

struct FastCreatorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focusBinding: FocusState<FastCreatorField?>.Binding
    let fieldType: FastCreatorField
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            focusBinding.wrappedValue == fieldType ? Color.accentColor : Color(.separator),
                            lineWidth: focusBinding.wrappedValue == fieldType ? 2 : 0.5
                        )
                }
                .focused(focusBinding, equals: fieldType)
                .id("\(fieldType)Field")
        }
    }
}

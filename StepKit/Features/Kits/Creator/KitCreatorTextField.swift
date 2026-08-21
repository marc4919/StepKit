import SwiftUI

struct KitCreatorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var focusBinding: FocusState<KitCreatorField?>.Binding
    let fieldType: KitCreatorField
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

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
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var accessibilityIdentifier: String {
        switch fieldType {
        case .description:
            return "kitCreator.description"
        case .obstacles:
            return "kitCreator.obstacles"
        case .time:
            return "kitCreator.availableTime"
        }
    }
}

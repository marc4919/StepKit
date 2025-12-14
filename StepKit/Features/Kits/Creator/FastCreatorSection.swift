import SwiftUI

struct FastCreatorSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 20) {
                content
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

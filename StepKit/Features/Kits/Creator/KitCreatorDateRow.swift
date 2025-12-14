import SwiftUI

struct KitCreatorDateRow: View {
    @Binding var date: Date
    let isDateInPast: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fecha objetivo")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient.accentWithOpacity( 0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(date, format: .dateTime.weekday(.wide))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text(date, format: .dateTime.day().month(.wide).year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fecha objetivo")
            .accessibilityValue(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
            .accessibilityHint("Toca para cambiar la fecha objetivo")

            if isDateInPast {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("La fecha seleccionada ya ha pasado")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
        }
    }
}

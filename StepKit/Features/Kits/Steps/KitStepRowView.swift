import SwiftUI
import SwiftData

struct KitStepRowView: View {
    let stepEntity: StepEntity
    let index: Int
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Indicador de paso
                ZStack {
                    Circle()
                        .fill(stepEntity.isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if stepEntity.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(index)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stepEntity.stepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(stepEntity.descriptionShort)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Tiempo estimado y fecha
                    HStack(spacing: 8) {
                        if stepEntity.estimateMinutes > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(stepEntity.estimateMinutes.formattedDuration())
                            }
                        }
                        if let deadline = stepEntity.suggestedDeadline {
                            if stepEntity.estimateMinutes > 0 {
                                Text("•")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(deadline, format: .dateTime.day().month(.abbreviated))
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 74)
            }
        }
    }
}

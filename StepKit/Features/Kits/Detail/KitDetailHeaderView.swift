import SwiftUI
import SwiftData

struct KitDetailHeaderView: View {
    let kitEntity: GoalEntity
    @State private var displayedProgress: Double
    @State private var displayedPercentage: Int
    
    init(kitEntity: GoalEntity) {
        self.kitEntity = kitEntity
        let progress = kitEntity.computedProgress
        _displayedProgress = State(initialValue: progress)
        _displayedPercentage = State(initialValue: Int(progress * 100))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icono con progreso
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                kitEntity.isCompleted ? Color.green.opacity(0.2) : Color.accentHighlight.opacity(0.2),
                                kitEntity.isCompleted ? Color.green.opacity(0.05) : Color.accentColor.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                // Progreso circular
                Circle()
                    .stroke(
                        kitEntity.isCompleted ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.15),
                        lineWidth: 6
                    )
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: displayedProgress)
                    .stroke(
                        kitEntity.isCompleted
                            ? LinearGradient.completedGradient
                            : LinearGradient.accentGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.7), value: displayedProgress)

                // Contenido central
                if kitEntity.isCompleted {
                    Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.green)
                } else {
                    Text("\(displayedPercentage)%")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.7), value: displayedPercentage)
                }
            }

            // Título y KPI
            VStack(spacing: 8) {
                Text(kitEntity.planTitle)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(kitEntity.kpi)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            // Contador de pasos
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)

                Text(String(localized: "\(kitEntity.steps.filter { $0.isCompleted }.count) de \(kitEntity.steps.count) pasos completados"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7)) {
                displayedProgress = kitEntity.computedProgress
                displayedPercentage = Int(kitEntity.computedProgress * 100)
            }
        }
        .onChange(of: kitEntity.computedProgress) { _, newValue in
             withAnimation(.easeInOut(duration: 0.7)) {
                 displayedProgress = newValue
                 displayedPercentage = Int(newValue * 100)
             }
        }
    }
}

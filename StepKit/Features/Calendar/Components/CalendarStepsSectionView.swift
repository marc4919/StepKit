//
//  CalendarStepsSectionView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import SwiftData

struct CalendarStepsSectionView: View {
    let steps: [StepEntity]
    @Binding var stepsExpanded: Bool
    let onToggleStep: (StepEntity) -> Void
    
    private var stepsToShow: [StepEntity] {
        stepsExpanded ? steps : Array(steps.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)

                Text("Pasos del día")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(steps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(stepsToShow, id: \.id) { step in
                    SwipeableStepRow(step: step, onToggle: { onToggleStep(step) })
                }

                if steps.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stepsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(stepsExpanded ? "Ver menos" : "+ \(steps.count - 3) más")
                            Image(systemName: stepsExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Swipeable Step Row
struct SwipeableStepRow: View {
    let step: StepEntity
    let onToggle: () -> Void
    
    var body: some View {
        NavigationLink(value: StepNavigation(id: step.id)) {
            CompactStepRow(step: step)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(step.isCompleted ? "Desmarcar" : "Completar", systemImage: step.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(step.isCompleted ? .orange : .green)
        }
    }
}

// MARK: - Compact Step Row
struct CompactStepRow: View {
    let step: StepEntity
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.stepTitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if step.estimateMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(CalendarHelpers.formatMinutes(step.estimateMinutes))
                                .font(.caption2)
                        }
                    }

                    if let kitTitle = step.goal?.title, !kitTitle.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text(kitTitle)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

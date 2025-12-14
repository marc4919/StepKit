//
//  CalendarKitsSectionView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import SwiftData

struct CalendarKitsSectionView: View {
    let goals: [GoalEntity]
    let selectedDate: Date
    
    private var deadlineSubtitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Kits que finalizan hoy"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Kits que finalizan mañana"
        } else {
            return "Kits que finalizan el \(selectedDate.formatted(.dateTime.day().month(.wide)))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)

                        Text("Deadlines")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Text(deadlineSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !goals.isEmpty {
                    Text("\(goals.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            if goals.isEmpty {
                CalendarEmptyStateView()
            } else {
                VStack(spacing: 12) {
                    ForEach(goals) { goal in
                        CalendarKitRow(goal: goal)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Empty State
struct CalendarEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.accentWithOpacity(0.6))

            Text("Sin kits para este día")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Pulsa + para crear uno")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Kit Row
struct CalendarKitRow: View {
    let goal: GoalEntity
    let progress: Double
    
    init(goal: GoalEntity) {
        self.goal = goal
        self.progress = goal.computedProgress
    }
    
    var body: some View {
        NavigationLink(value: GoalNavigation(id: goal.id)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient.accentGradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    let pendingSteps = goal.steps.filter { !$0.isCompleted }.count
                    Text("\(pendingSteps) paso\(pendingSteps == 1 ? "" : "s") pendiente\(pendingSteps == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

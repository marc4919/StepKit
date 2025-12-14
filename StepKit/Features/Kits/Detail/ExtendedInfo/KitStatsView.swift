//
//  KitStatsView.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI

struct KitStatsView: View {
    let goalEntity: GoalEntity
    
    var body: some View {
        HStack(spacing: 12) {
            // Progreso
            statCard(
                value: "\(Int(goalEntity.computedProgress * 100))%",
                label: "Progreso",
                icon: "chart.pie.fill",
                color: goalEntity.isCompleted ? .green : .accentColor
            )

            // Pasos completados
            statCard(
                value: "\(goalEntity.steps.filter { $0.isCompleted }.count)/\(goalEntity.steps.count)",
                label: "Pasos",
                icon: "list.bullet.circle.fill",
                color: .orange
            )

            // Tiempo total
            statCard(
                value: formatTotalTime(),
                label: "Tiempo",
                icon: "clock.fill",
                color: .purple
            )
        }
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func formatTotalTime() -> String {
        let totalMinutes = goalEntity.steps.reduce(0) { $0 + $1.estimateMinutes }
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h\(minutes)m"
            }
        }
    }
}

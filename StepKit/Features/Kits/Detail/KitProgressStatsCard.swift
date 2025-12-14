//
//  KitProgressStatsCard.swift
//  StepKit
//
//  Extracted from ExtendedKitInfoView.swift
//

import SwiftUI

struct KitProgressStatsCard: View {
    let progressPercent: Int
    let completedSteps: Int
    let totalSteps: Int
    let totalTimeFormatted: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Progreso
            statCard(
                value: "\(progressPercent)%",
                label: "Progreso",
                icon: "chart.pie.fill",
                color: isCompleted ? .green : .accentColor
            )

            // Pasos completados
            statCard(
                value: "\(completedSteps)/\(totalSteps)",
                label: "Pasos",
                icon: "list.bullet.circle.fill",
                color: .orange
            )

            // Tiempo total
            statCard(
                value: totalTimeFormatted,
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
}

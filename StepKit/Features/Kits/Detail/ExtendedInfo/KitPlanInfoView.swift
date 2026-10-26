//
//  KitPlanInfoView.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI

struct KitPlanInfoView: View {
    let goalEntity: GoalEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar.badge.clock", title: String(localized: "Planificación"))

            VStack(spacing: 0) {
                // Horizonte
                infoRow(
                    icon: "hourglass",
                    iconColor: .accentColor,
                    title: String(localized: "Horizonte"),
                    value: String(localized: "\(goalEntity.horizonDays) días"),
                    showDivider: goalEntity.dueDate != nil
                )

                // Fecha objetivo
                if let dueDate = goalEntity.dueDate {
                    infoRow(
                        icon: "calendar",
                        iconColor: .orange,
                        title: String(localized: "Fecha objetivo"),
                        value: dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()),
                        showDivider: true
                    )
                }

                // Días restantes
                if let dueDate = goalEntity.dueDate, !goalEntity.isCompleted {
                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                    infoRow(
                        icon: daysRemaining < 0 ? "exclamationmark.triangle.fill" : "clock.badge.checkmark",
                        iconColor: daysRemaining < 0 ? .red : (daysRemaining <= 3 ? .orange : .green),
                        title: String(localized: "Días restantes"),
                        value: daysRemaining < 0 ? String(localized: "Vencido hace \(abs(daysRemaining)) días") : String(localized: "\(daysRemaining) días"),
                        showDivider: false
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 4)
    }
    
    private func infoRow(icon: String, iconColor: Color, title: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading, 62)
            }
        }
    }
}

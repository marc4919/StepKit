//
//  PremiumFeaturesList.swift
//  StepKit
//
//  Extracted from SubscriptionView.swift
//

import SwiftUI

// MARK: - Feature Benefit Row

struct FeatureBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
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

// MARK: - Premium Features List

struct PremiumFeaturesList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)

                Text("Beneficios Premium")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 0) {
                FeatureBenefitRow(
                    icon: "infinity",
                    iconColor: .accentColor,
                    title: "Objetivos ilimitados",
                    description: "Crea tantos objetivos como quieras",
                    showDivider: true
                )

                FeatureBenefitRow(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "IA sin limites",
                    description: "Genera planes con IA de forma ilimitada",
                    showDivider: true
                )

                FeatureBenefitRow(
                    icon: "icloud",
                    iconColor: .accentHighlight,
                    title: "Sincronizacion en la nube",
                    description: "Accede desde cualquier dispositivo",
                    showDivider: true
                )

                FeatureBenefitRow(
                    icon: "bell.badge",
                    iconColor: .orange,
                    title: "Recordatorios personalizados",
                    description: "Notificaciones inteligentes adaptadas",
                    showDivider: true
                )

                FeatureBenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "Analisis avanzado",
                    description: "Estadisticas detalladas de tu progreso",
                    showDivider: false
                )
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

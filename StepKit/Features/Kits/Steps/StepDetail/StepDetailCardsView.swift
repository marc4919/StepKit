//
//  StepDetailCardsView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import SwiftData

struct StepDetailCardsView: View {
    @Bindable var stepEntity: StepEntity
    
    var body: some View {
        VStack(spacing: 24) {
            // Metadatos (tiempo, fecha, esfuerzo)
            StepDetailsCard(stepEntity: stepEntity)

            // Descripción
            if !stepEntity.descriptionLong.isEmpty {
                StepDescriptionCard(stepEntity: stepEntity)
            }

            // Adaptación
            if !stepEntity.adaptsTo.isEmpty {
                StepAdaptationCard(adaptsTo: stepEntity.adaptsTo)
            }

            // Premium
            if stepEntity.blockedByPremium {
                StepPremiumCard()
            }
        }
    }
}

// MARK: - Details Card
struct StepDetailsCard: View {
    @Bindable var stepEntity: StepEntity
    
    var body: some View {
        VStack(spacing: 0) {
            // Tiempo estimado
            StepDetailRow(
                icon: "clock.fill",
                iconColor: .accentColor,
                title: "Tiempo estimado",
                value: StepDetailHelpers.formatMinutes(stepEntity.estimateMinutes),
                showDivider: true
            )
            
            // Fecha sugerida
            if let deadline = stepEntity.suggestedDeadline {
                StepDetailRow(
                    icon: "calendar",
                    iconColor: .purple,
                    title: "Fecha sugerida",
                    value: deadline.formatted(.dateTime.day().month(.wide)),
                    showDivider: true
                )
            }
            
            // Nivel de esfuerzo
            StepDetailRow(
                icon: StepDetailHelpers.effortIcon(for: stepEntity.effortLevel),
                iconColor: StepDetailHelpers.effortColor(for: stepEntity.effortLevel),
                title: "Nivel de esfuerzo",
                showDivider: false,
                trailing: {
                    StepEffortIndicator(effortLevel: stepEntity.effortLevel)
                }
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Detail Row
struct StepDetailRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let showDivider: Bool
    @ViewBuilder let trailing: () -> Trailing
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }
}

extension StepDetailRow where Trailing == Text {
    init(icon: String, iconColor: Color, title: String, value: String, showDivider: Bool) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.showDivider = showDivider
        self.trailing = {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Effort Indicator
struct StepEffortIndicator: View {
    let effortLevel: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(StepDetailHelpers.effortLevelText(for: effortLevel))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(StepDetailHelpers.effortColor(for: effortLevel))
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < StepDetailHelpers.effortLevelIndex(for: effortLevel) ? StepDetailHelpers.effortColor(for: effortLevel) : Color(.systemGray4))
                        .frame(width: 6, height: 14 - CGFloat(index) * 2)
                }
            }
        }
    }
}

// MARK: - Description Card
struct StepDescriptionCard: View {
    @Bindable var stepEntity: StepEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)

                Text("Descripción")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Descripción corta en negrita
                Text(stepEntity.descriptionShort)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Descripción larga dividida en párrafos
                ForEach(Array(StepDetailHelpers.formattedParagraphs(from: stepEntity.descriptionLong).enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Adaptation Card
struct StepAdaptationCard: View {
    let adaptsTo: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(LinearGradient.accentGradient)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Adaptado para ti")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(adaptsTo)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(LinearGradient.accentWithOpacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LinearGradient.accentWithOpacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Premium Card
struct StepPremiumCard: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 1, green: 0.65, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contenido Premium")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Requiere StepKit Pro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    // Navegar a suscripción
                } label: {
                    Text("Desbloquear")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LinearGradient.accentGradient)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

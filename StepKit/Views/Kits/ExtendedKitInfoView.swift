//
//  ExtendedKitInfoView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

struct ExtendedKitInfoView: View {
    let goal: Goal
    @Environment(\.dismiss) private var dismiss
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header con icono
                    headerSection
                    
                    // Estadísticas rápidas
                    statsSection
                    
                    // Información del plan
                    planInfoSection
                    
                    // Categorías y tags
                    if !goal.meta.tags.isEmpty || !goal.meta.type.isEmpty {
                        categoriesSection
                    }
                    
                    // Riesgos
                    if !goal.risks.isEmpty {
                        risksSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Detalles del Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icono con glow
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goal.isCompleted ? Color.green.opacity(0.3) : accentHighlight.opacity(0.3),
                                goal.isCompleted ? Color.green.opacity(0.1) : accentBlue.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)
                
                // Círculo de fondo
                Circle()
                    .fill(
                        LinearGradient(
                            colors: goal.isCompleted
                                ? [Color.green.opacity(0.2), Color.green.opacity(0.1)]
                                : [accentHighlight.opacity(0.2), accentBlue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                // Icono
                Image(systemName: goal.isCompleted ? "checkmark.seal.fill" : "info.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        goal.isCompleted
                            ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            // Título
            VStack(spacing: 6) {
                Text(goal.planTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(goal.kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            // Progreso
            statCard(
                value: "\(Int(goal.progress * 100))%",
                label: "Progreso",
                icon: "chart.pie.fill",
                color: goal.isCompleted ? .green : accentBlue
            )
            
            // Pasos completados
            statCard(
                value: "\(goal.steps.filter { $0.isCompleted }.count)/\(goal.steps.count)",
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
    
    // MARK: - Plan Info Section
    private var planInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar.badge.clock", title: "Planificación")
            
            VStack(spacing: 0) {
                // Horizonte
                infoRow(
                    icon: "hourglass",
                    iconColor: accentBlue,
                    title: "Horizonte",
                    value: "\(goal.horizonDays) días",
                    showDivider: goal.dueDate != nil
                )
                
                // Fecha objetivo
                if let dueDate = goal.dueDate {
                    infoRow(
                        icon: "calendar",
                        iconColor: .orange,
                        title: "Fecha objetivo",
                        value: dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()),
                        showDivider: true
                    )
                }
                
                // Días restantes
                if let dueDate = goal.dueDate, !goal.isCompleted {
                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                    infoRow(
                        icon: daysRemaining < 0 ? "exclamationmark.triangle.fill" : "clock.badge.checkmark",
                        iconColor: daysRemaining < 0 ? .red : (daysRemaining <= 3 ? .orange : .green),
                        title: "Días restantes",
                        value: daysRemaining < 0 ? "Vencido hace \(abs(daysRemaining)) días" : "\(daysRemaining) días",
                        showDivider: false
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "tag.fill", title: "Categorías")
            
            VStack(alignment: .leading, spacing: 16) {
                // Tipo
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accentBlue.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: typeIcon(for: goal.meta.type))
                            .font(.system(size: 16))
                            .foregroundColor(accentBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tipo de objetivo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(localizedType(goal.meta.type))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                // Tags
                if !goal.meta.tags.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Etiquetas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(goal.meta.tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Image(systemName: "number")
                                        .font(.caption2)
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: [accentHighlight.opacity(0.15), accentBlue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(accentBlue)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Risks Section
    private var risksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "exclamationmark.shield.fill", title: "Riesgos Identificados")
            
            VStack(spacing: 10) {
                ForEach(Array(goal.risks.enumerated()), id: \.offset) { index, risk in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        
                        Text(risk)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.08), Color.orange.opacity(0.04)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(accentBlue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
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
    
    private func formatTotalTime() -> String {
        let totalMinutes = goal.steps.reduce(0) { $0 + $1.estimateMinutes }
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
    
    private func typeIcon(for type: String) -> String {
        switch type.lowercased() {
        case "health": return "heart.fill"
        case "learning": return "book.fill"
        case "fitness": return "figure.run"
        case "productivity": return "chart.bar.fill"
        case "finance": return "dollarsign.circle.fill"
        case "creative": return "paintbrush.fill"
        default: return "star.fill"
        }
    }
    
    private func localizedType(_ type: String) -> String {
        switch type.lowercased() {
        case "health": return "Salud"
        case "learning": return "Aprendizaje"
        case "fitness": return "Fitness"
        case "productivity": return "Productividad"
        case "finance": return "Finanzas"
        case "creative": return "Creatividad"
        case "setup": return "Configuración"
        default: return type.capitalized
        }
    }
}

// MARK: - Flow Layout (para tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    ExtendedKitInfoView(goal: .preview)
}

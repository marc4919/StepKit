//
//  ExtendedKitInfoView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI
import SwiftData

struct ExtendedKitInfoView: View {
    let goalEntity: GoalEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncManager) private var syncManager
    @State private var showingDeleteConfirmation = false
    @State private var kitNotificationsEnabled: Bool = true
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header con icono
                    headerSection

                    // Estadísticas rápidas
                    statsSection

                    // Tipo de objetivo
                    if !goalEntity.metaType.isEmpty {
                        categoriesSection
                    }

                    // Información del plan
                    planInfoSection

                    // Riesgos
                    if !goalEntity.risks.isEmpty {
                        risksSection
                    }

                    // Notificaciones del kit
                    notificationsSection

                    // Botón eliminar
                    deleteSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Detalles del Kit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingDeleteConfirmation) {
            deleteConfirmationSheet
        }
        .onAppear {
            kitNotificationsEnabled = goalEntity.notificationsEnabled
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "bell.fill", title: "Recordatorios")

            Toggle(isOn: $kitNotificationsEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 36, height: 36)

                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notificaciones")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Recordar antes de cada paso")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.accentColor)
            .disabled(!globalNotificationsEnabled)
            .opacity(globalNotificationsEnabled ? 1 : 0.5)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: kitNotificationsEnabled) { _, newValue in
                updateKitNotificationsSetting(enabled: newValue)
            }

            if !globalNotificationsEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Activa las notificaciones globales en tu Perfil")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    private func updateKitNotificationsSetting(enabled: Bool) {
        goalEntity.notificationsEnabled = enabled
        goalEntity.markModified()

        if enabled {
            Task {
                await NotificationService.shared.scheduleNotifications(for: goalEntity)
            }
        } else {
            NotificationService.shared.cancelNotifications(for: goalEntity)
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Delete Confirmation Sheet
    private var deleteConfirmationSheet: some View {
        VStack(spacing: 24) {
            // Icono
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "trash")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.top, 24)

            // Texto
            VStack(spacing: 8) {
                Text("¿Eliminar este kit?")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(goalEntity.planTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("Esta acción no se puede deshacer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Botones
            VStack(spacing: 12) {
                Button(role: .destructive) {
                    deleteKit()
                } label: {
                    Text("Eliminar")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    showingDeleteConfirmation = false
                } label: {
                    Text("Cancelar")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Delete Section
    private var deleteSection: some View {
        Button {
            showingDeleteConfirmation = true
        } label: {
            HStack {
                Spacer()
                Label("Eliminar kit", systemImage: "trash")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .foregroundColor(.red)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 20)
    }

    // MARK: - Actions
    private func deleteKit() {
        let now = Date()

        // Soft delete directo (mismo patrón que GoalsListView)
        goalEntity.markAsDeleted(at: now)

        // Cascade: soft delete de todos los steps
        for step in goalEntity.steps {
            step.deletedAt = now
            step.markModified()
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Cerrar sheets
        showingDeleteConfirmation = false
        dismiss()

        // Trigger sync
        syncManager?.handleDataChange()
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
                                goalEntity.isCompleted ? Color.green.opacity(0.3) : Color.accentHighlight.opacity(0.3),
                                goalEntity.isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1),
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
                        goalEntity.isCompleted
                            ? LinearGradient.completedWithOpacity( 0.2)
                            : LinearGradient.accentWithOpacity( 0.2)
                    )
                    .frame(width: 64, height: 64)

                // Icono
                Image(systemName: goalEntity.isCompleted ? "checkmark.seal.fill" : "info.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        goalEntity.isCompleted
                            ? LinearGradient.completedGradient
                            : LinearGradient.accentGradient
                    )
            }

            // Título
            VStack(spacing: 6) {
                Text(goalEntity.planTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(goalEntity.kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    // MARK: - Stats Section
    private var statsSection: some View {
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

    // MARK: - Plan Info Section
    private var planInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "calendar.badge.clock", title: "Planificación")

            VStack(spacing: 0) {
                // Horizonte
                infoRow(
                    icon: "hourglass",
                    iconColor: .accentColor,
                    title: "Horizonte",
                    value: "\(goalEntity.horizonDays) días",
                    showDivider: goalEntity.dueDate != nil
                )

                // Fecha objetivo
                if let dueDate = goalEntity.dueDate {
                    infoRow(
                        icon: "calendar",
                        iconColor: .orange,
                        title: "Fecha objetivo",
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: typeIcon(for: goalEntity.metaType))
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Tipo de objetivo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(localizedType(goalEntity.metaType))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Risks Section
    private var risksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "exclamationmark.shield.fill", title: "Riesgos Identificados")

            VStack(spacing: 10) {
                ForEach(Array(goalEntity.risks.enumerated()), id: \.offset) { index, risk in
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

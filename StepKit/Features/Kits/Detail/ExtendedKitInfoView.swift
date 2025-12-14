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
                    ExtendedKitInfoHeaderView(goalEntity: goalEntity)

                    // Estadísticas rápidas
                    KitStatsView(goalEntity: goalEntity)

                    // Tipo de objetivo
                    if !goalEntity.metaType.isEmpty {
                        KitCategoriesView(metaType: goalEntity.metaType)
                    }

                    // Información del plan
                    KitPlanInfoView(goalEntity: goalEntity)

                    // Riesgos
                    if !goalEntity.risks.isEmpty {
                        KitRisksView(risks: goalEntity.risks)
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
            DeleteConfirmationSheet(
                kitTitle: goalEntity.planTitle,
                onDelete: { deleteKit() },
                onCancel: { showingDeleteConfirmation = false }
            )
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
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notificaciones")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Recordar antes de cada paso")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
            .foregroundStyle(.red)
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
    
    // MARK: - Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
    }
}

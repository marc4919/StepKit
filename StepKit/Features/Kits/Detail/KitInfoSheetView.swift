//
//  KitInfoSheetView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI
import SwiftData

struct KitInfoSheetView: View {
    let goalEntity: GoalEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncManager) private var syncManager
    @State private var showingDeleteConfirmation = false
    @State private var showingEdit = false
    @State private var kitNotificationsEnabled: Bool = true
    @AppStorage("globalNotificationsEnabled") private var globalNotificationsEnabled = true


    var body: some View {
        NavigationStack {
            List {
                heroSection
                goalSection
                planSection
                if !goalEntity.risks.isEmpty { risksSection }
                notificationsSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background(alignment: .top) { BrandGlow() }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Detalles del Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("kitInfo.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") { showingEdit = true }
                        .accessibilityIdentifier("kit.edit")
                        .accessibilityHint("Permite cambiar el título y el indicador de éxito del Kit")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            KitEditSheetView(kitEntity: goalEntity)
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

    // MARK: - Cabecera: título, anillo y cifras, como en el Kit

    private var done: Int { goalEntity.steps.filter { $0.isCompleted && $0.deletedAt == nil }.count }
    private var total: Int { goalEntity.steps.filter { $0.deletedAt == nil }.count }
    private var totalMinutes: Int { goalEntity.steps.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.estimateMinutes } }

    private var heroSection: some View {
        Section {
            HStack(alignment: .center, spacing: 16) {
                ProgressRing(done: done, total: total, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(goalEntity.planTitle)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        MetaChip(symbol: "checkmark.circle", text: String(localized: "\(done) de \(total)"), color: MetaTint.done)
                        MetaChip(symbol: Symbols.time, text: KitCreatorViewModel.durationText(totalMinutes), color: MetaTint.time)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
        }
    }

    // MARK: - Objetivo

    private var goalSection: some View {
        Section("Objetivo") {
            if !goalEntity.kpi.isEmpty {
                infoRow(symbol: "checklist", color: .green, title: String(localized: "Cómo sabrás que está listo"), value: goalEntity.kpi)
            }
            if !goalEntity.metaType.isEmpty {
                infoRow(symbol: typeIcon(goalEntity.metaType), color: .accentColor, title: String(localized: "Tipo"), value: localizedType(goalEntity.metaType))
            }
        }
    }

    // MARK: - Planificación

    private var planSection: some View {
        Section("Planificación") {
            if let dueDate = goalEntity.dueDate {
                infoRow(symbol: Symbols.wantedDate, color: MetaTint.date, title: String(localized: "Fecha deseada"),
                        value: dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                if !goalEntity.isCompleted {
                    let remaining = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                                    to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
                    infoRow(symbol: "clock.badge.checkmark", color: remaining < 0 ? .red : .green, title: String(localized: "Días restantes"),
                            value: remaining < 0 ? String(localized: "Vencido hace \(abs(remaining)) días") : String(localized: "\(remaining) días"))
                }
            }
            infoRow(symbol: "hourglass", color: MetaTint.time, title: String(localized: "Horizonte"), value: String(localized: "\(goalEntity.horizonDays) días"))
            infoRow(symbol: Symbols.calendar, color: .secondary, title: String(localized: "Creado"),
                    value: goalEntity.createdAt.formatted(.dateTime.day().month(.abbreviated).year()))
        }
    }

    // MARK: - A tener en cuenta

    private var risksSection: some View {
        Section("A tener en cuenta") {
            ForEach(Array(goalEntity.risks.enumerated()), id: \.offset) { _, risk in
                let topic = RiskTopic(risk)
                Label {
                    Text(risk).font(.subheadline)
                } icon: {
                    IconChip(symbol: topic.symbol, color: topic.tint, size: 28)
                }
            }
        }
    }

    // MARK: - Recordatorios

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $kitNotificationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avisos de este Kit")
                        Text(globalNotificationsEnabled ? String(localized: "El resumen de cada mañana y las sesiones")
                                                        : String(localized: "Activa los recordatorios en Perfil"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    IconChip(symbol: "bell.fill", color: .red, size: 28)
                }
            }
            .disabled(!globalNotificationsEnabled)
            .onChange(of: kitNotificationsEnabled) { _, newValue in
                updateKitNotificationsSetting(enabled: newValue)
            }
        } header: {
            Text("Recordatorios")
        }
    }

    // MARK: - Filas

    private func infoRow(symbol: String, color: Color, title: String, value: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            IconChip(symbol: symbol, color: color, size: 28)
        }
    }

    private func typeIcon(_ type: String) -> String {
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
        case "health": return String(localized: "Salud")
        case "learning": return String(localized: "Aprendizaje")
        case "fitness": return String(localized: "Fitness")
        case "productivity": return String(localized: "Productividad")
        case "finance": return String(localized: "Finanzas")
        case "creative": return String(localized: "Creatividad")
        case "setup": return String(localized: "Configuración")
        case "personal": return String(localized: "Personal")
        default: return type.capitalized
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

    // MARK: - Eliminar

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                Label("Eliminar Kit", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("kitInfo.delete")
        }
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
}

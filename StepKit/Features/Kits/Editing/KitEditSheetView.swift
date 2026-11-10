//
//  KitEditSheetView.swift
//  StepKit
//

import SwiftData
import SwiftUI

struct KitEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager

    let kitEntity: GoalEntity

    @State private var draft: KitEditDraft
    @State private var showingSaveError = false

    init(kitEntity: GoalEntity) {
        self.kitEntity = kitEntity
        _draft = State(initialValue: KitEditDraft(kit: kitEntity))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título del Kit", text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("kitEdit.title")

                    TextField("Indicador de éxito", text: $draft.kpi, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("kitEdit.kpi")
                } header: {
                    Text("Contenido")
                } footer: {
                    Text("Estos cambios se guardarán en el Kit y se sincronizarán con tus otros dispositivos.")
                }

                Section {
                    finalDatePicker
                    if finalDateLeavesStepsBehind, let target = draft.targetDate {
                        Label {
                            Text(String(localized: "Algún paso quedaría después de la fecha final del Kit, el \(target.formatted(.dateTime.day().month(.abbreviated)))."))
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .centeredNavigationTitle("Editar Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("kitEdit.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(!draft.isValid || !draft.hasChanges(comparedTo: kitEntity))
                    .accessibilityIdentifier("kitEdit.save")
                }
            }
            .alert("No se pudo guardar el Kit", isPresented: $showingSaveError) {
                Button("Aceptar", role: .cancel) { }
            } message: {
                Text("Los cambios no se han confirmado. Inténtalo de nuevo.")
            }
        }
        .interactiveDismissDisabled(draft.hasChanges(comparedTo: kitEntity))
    }

    private var finalDatePicker: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let shown = draft.targetDate ?? kitEntity.dueDate ?? today
        // Un Kit ya vencido muestra su fecha, aunque las nuevas empiecen hoy.
        return DatePicker(selection: Binding(
            get: { shown },
            set: { newValue in withAnimation(.smooth) { draft.targetDate = Calendar.current.startOfDay(for: newValue) } }
        ), in: min(today, shown)..., displayedComponents: .date) {
            Label { Text("Fecha final") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
        }
        .accessibilityIdentifier("kitEdit.finalDate")
    }

    /// Los pasos sin día elegido se reparten solos: solo cuentan los que tienen el suyo.
    private var finalDateLeavesStepsBehind: Bool {
        guard draft.changesTargetDate(of: kitEntity), let target = draft.targetDate,
              let last = ManualKit.lastFixedDate(of: kitEntity) else { return false }
        return Calendar.current.startOfDay(for: last) > Calendar.current.startOfDay(for: target)
    }

    private func save() {
        guard let ownerID = authManager.currentUser?.id else {
            showingSaveError = true
            return
        }

        do {
            let datesChange = draft.changesTargetDate(of: kitEntity)
            try modelContext.transaction {
                _ = try draft.apply(to: kitEntity, expectedOwnerID: ownerID)
                if datesChange { ManualKit.finalDateChanged(of: kitEntity) }
            }
            if datesChange { NotificationService.shared.refreshStepReminders() }
            syncManager?.handleDataChange()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let kit = GoalEntity(
        planTitle: "Preparar una carrera",
        horizonDays: 30,
        kpi: "Completar 5 km sin pausas"
    )
    container.mainContext.insert(kit)

    return KitEditSheetView(kitEntity: kit)
        .modelContainer(container)
        .environment(AuthManager())
}

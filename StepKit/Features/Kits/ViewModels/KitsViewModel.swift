//
//  KitsViewModel.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI
import SwiftData

@Observable
final class KitsViewModel {
    // MARK: - Navigation & Selection State
    var selectedKitEntity: GoalEntity?
    var selectedKitId: UUID?
    /// Pasos abiertos encima del plan del Kit elegido. Vaciarla vuelve al plan.
    var detailPath: [StepEntity] = []
    /// El plan del Kit elegido tiene otra pantalla encima (paso, asistente, resultado…).
    var isKitPlanCovered = false
    /// Kits que se están eliminando: salen de la lista con animación antes del borrado real.
    var leavingKitIDs: Set<UUID> = []
    var selectedStepEntity: StepEntity?
    /// Kit cuya revisión del resultado se abre encima de su plan al navegar a él.
    var reviewOnOpenKitID: UUID?
    
    // MARK: - UI State
    var showingKitCreator = false
    var animateEmptyState = false
    var showingDeleteConfirmation = false
    var kitEntityToDelete: GoalEntity?
    
    // MARK: - Actions
    
    func selectKit(_ kit: GoalEntity) {
        selectedKitEntity = kit
        selectedKitId = kit.id
    }
    
    /// Abre el plan, también si el Kit ya estaba elegido con un paso encima.
    func openKitPlan(_ kit: GoalEntity) {
        detailPath = []
        selectKit(kit)
    }

    /// Con dos columnas, el paso se abre encima de su Kit: así atrás siempre lleva al plan.
    func continueStep(_ step: StepEntity, of kit: GoalEntity) {
        guard selectedKitId != kit.id else {
            detailPath = [step]
            return
        }
        openKitPlan(kit)
        // Al cambiar de Kit la columna descarta una ruta puesta a la vez: el paso entra justo después.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard selectedKitId == kit.id else { return }
            detailPath = [step]
        }
    }

    /// Abre un Kit recién creado. Se busca en la base de datos: la lista aún puede no haberlo recibido.
    func openCreatedKit(id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == id })
        if let kit = try? context.fetch(descriptor).first { selectKit(kit) }
    }

    func clearSelection() {
        selectedKitEntity = nil
        selectedKitId = nil
        selectedStepEntity = nil
        detailPath = []
    }
    
    func prepareForDeletion(_ kit: GoalEntity) {
        kitEntityToDelete = kit
        showingDeleteConfirmation = true
    }
    
    func cancelDeletion() {
        showingDeleteConfirmation = false
        kitEntityToDelete = nil
    }
    
    func deleteKit(_ kit: GoalEntity, syncManager: SyncManager?) {
        let now = Date()
        
        // Soft delete del kit
        kit.markAsDeleted(at: now)
        
        // Cascade: soft delete de todos los steps
        for step in kit.steps {
            step.deletedAt = now
            step.markModified()
        }
        
        // Limpiar selección si es necesario
        if selectedKitId == kit.id {
            clearSelection()
        }
        
        // Guardar ya: la lista (@Query) solo se refresca tras guardar, y sin esto el Kit reaparece.
        try? kit.modelContext?.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Trigger sync
        #if DEBUG
        print("🗑️ KitsViewModel: Deleting kit, syncManager is \(syncManager == nil ? "nil" : "available")")
        #endif
        syncManager?.handleDataChange()
        
        kitEntityToDelete = nil
    }
}

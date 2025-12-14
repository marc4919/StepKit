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
    var selectedStepEntity: StepEntity?
    var navigationPath: [UUID] = []
    
    // MARK: - UI State
    var showingFastCreator = false
    var animateEmptyState = false
    var showingDeleteConfirmation = false
    var kitEntityToDelete: GoalEntity?
    
    // MARK: - Actions
    
    func selectKit(_ kit: GoalEntity) {
        selectedKitEntity = kit
        selectedKitId = kit.id
    }
    
    func clearSelection() {
        selectedKitEntity = nil
        selectedKitId = nil
        selectedStepEntity = nil
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
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Trigger sync
        #if DEBUG
        print("🗑️ KitsViewModel: Deleting kit, syncManager is \(syncManager == nil ? "nil" : "available")")
        #endif
        syncManager?.handleDataChange()
        
        kitEntityToDelete = nil
    }
}

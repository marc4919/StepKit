//
//  SyncService.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation
import SwiftData
import SwiftUI

/// Servicio principal de sincronización que orquesta la comunicación entre Core Data y el Backend
@Observable
final class SyncService {
    // MARK: - Properties
    
    var isSyncing = false
    var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSyncDate")
        }
    }
    
    private let authManager: AuthManager
    private let networkService: SyncNetworkService
    private var modelContext: ModelContext?
    
    // MARK: - Init
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        // Inicializamos el servicio de red con el HTTPClient por defecto
        let httpClient = HTTPClient()
        // Asumimos URL por defecto o la pasamos si es necesario. 
        // Para simplificar usamos la misma base que APIClient
        #if DEBUG
        let baseURL = "https://stepkitserver-production.up.railway.app"
        #else
        let baseURL = "https://stepkitserver-production.up.railway.app"
        #endif
        self.networkService = SyncNetworkService(client: httpClient, baseURL: baseURL)
    }
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Public API
    
    /// Ejecuta sync si ha pasado el intervalo mínimo
    func syncIfNeeded(minInterval: TimeInterval) async {
        guard let lastSync = lastSyncDate else {
            try? await syncAll()
            return
        }
        
        if Date().timeIntervalSince(lastSync) > minInterval {
            try? await syncAll()
        }
    }
    
    /// Ejecuta una sincronización completa
    func syncAll() async throws {
        guard !isSyncing else { return }
        guard let context = modelContext else { return }
        guard let token = authManager.token else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // 1. Recopilar cambios locales
            let request = try fetchLocalChanges(context: context)
            
            // 2. Enviar al servidor
            let response = try await networkService.syncBatch(request, token: token)
            
            // 3. Aplicar cambios del servidor
            try await applyServerChanges(response, context: context)
            
            // 4. Actualizar fecha
            lastSyncDate = Date()
            
        } catch {
            print("❌ Sync Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchLocalChanges(context: ModelContext) throws -> SyncBatchRequest {
        // Fetch Goals
        let goalDescriptor = FetchDescriptor<GoalEntity>()
        let allGoals = try context.fetch(goalDescriptor)
        
        // Fetch Steps
        let stepDescriptor = FetchDescriptor<StepEntity>()
        let allSteps = try context.fetch(stepDescriptor)
        
        // Filtrar modificados desde el último sync
        // Si lastSyncDate es nil, enviamos todo (primera sync)
        // O si updatedAt > lastSyncDate
        
        let kitsDTOs: [KitSyncDTO]
        let stepsDTOs: [StepSyncDTO]
        
        if let lastSync = lastSyncDate {
            kitsDTOs = allGoals
                .filter { $0.updatedAt > lastSync }
                .map { $0.toSyncDTO() }
            
            stepsDTOs = allSteps
                .filter { $0.updatedAt > lastSync }
                .map { $0.toSyncDTO() }
        } else {
            kitsDTOs = allGoals.map { $0.toSyncDTO() }
            stepsDTOs = allSteps.map { $0.toSyncDTO() }
        }
        
        return SyncBatchRequest(kits: kitsDTOs, steps: stepsDTOs)
    }
    
    private func applyServerChanges(_ response: SyncBatchResponse, context: ModelContext) async throws {
        // 1. Procesar Kits
        for kitDTO in response.kits {
            if let id = kitDTO.id {
                // Buscar existente
                let descriptor = FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == id })
                let existing = try context.fetch(descriptor).first
                
                if let existing {
                    if kitDTO.deleted {
                        context.delete(existing)
                    } else {
                        existing.update(from: kitDTO)
                    }
                } else if !kitDTO.deleted {
                    let newGoal = GoalEntity(fromSync: kitDTO)
                    context.insert(newGoal)
                }
            }
        }
        
        // Guardar cambios de Kits para que los Steps puedan encontrar sus padres
        try context.save()
        
        // 2. Procesar Steps
        for stepDTO in response.steps {
            if let id = stepDTO.id {
                let descriptor = FetchDescriptor<StepEntity>(predicate: #Predicate { $0.id == id })
                let existing = try context.fetch(descriptor).first
                
                if let existing {
                    if stepDTO.deleted {
                        context.delete(existing)
                    } else {
                        existing.update(from: stepDTO)
                    }
                } else if !stepDTO.deleted {
                    // Buscar padre
                    let kitId = stepDTO.kitId
                    let goalDescriptor = FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == kitId })
                    if let parent = try context.fetch(goalDescriptor).first {
                        let newStep = StepEntity(fromSync: stepDTO, goal: parent)
                        context.insert(newStep)
                    } else {
                        print("⚠️ Orphaned step received: \(stepDTO.title) for kit \(kitId)")
                    }
                }
            }
        }
        
        try context.save()
    }
}

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
@MainActor
final class SyncService {
    // MARK: - Properties
    
    var isSyncing = false
    var lastSyncDate: Date? {
        get {
            guard let key = syncCursorKey else { return nil }
            return preferences.object(forKey: key) as? Date
        }
        set {
            guard let key = syncCursorKey else { return }
            preferences.set(newValue, forKey: key)
        }
    }
    
    private let authManager: AuthManager
    private let networkService: any SyncNetworkServicing
    private let preferences: UserDefaults
    private var modelContext: ModelContext?

    private var ownerID: String? {
        guard let id = authManager.currentUser?.id, !id.isEmpty else { return nil }
        return id
    }

    private var syncCursorKey: String? {
        ownerID.map { "stepkit.lastSyncDate.\($0)" }
    }
    
    // MARK: - Init
    
    init(
        authManager: AuthManager,
        networkService: (any SyncNetworkServicing)? = nil,
        preferences: UserDefaults = .standard
    ) {
        self.authManager = authManager
        self.preferences = preferences
        // Inicializamos el servicio de red con el HTTPClient por defecto
        let httpClient = HTTPClient()
        // Asumimos URL por defecto o la pasamos si es necesario. 
        // Para simplificar usamos la misma base que APIClient
        #if DEBUG
        let baseURL = "https://stepkitserver-production.up.railway.app"
        #else
        let baseURL = "https://stepkitserver-production.up.railway.app"
        #endif
        self.networkService = networkService
            ?? SyncNetworkService(client: httpClient, baseURL: baseURL)
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
        guard let ownerID else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // 1. Recopilar cambios locales
            let request = try fetchLocalChanges(context: context, ownerID: ownerID)
            
            // 2. Enviar al servidor
            let response = try await networkService.syncBatch(request, token: token)
            
            // 3. Aplicar cambios del servidor
            try await applyServerChanges(response, context: context, ownerID: ownerID)
            
            // 4. Actualizar fecha
            lastSyncDate = Date()
            
        } catch {
            print("❌ Sync Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchLocalChanges(context: ModelContext, ownerID: String) throws -> SyncBatchRequest {
        // Fetch Goals
        let goalDescriptor = FetchDescriptor<GoalEntity>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        let allGoals = try context.fetch(goalDescriptor)
        
        // Fetch Steps
        let stepDescriptor = FetchDescriptor<StepEntity>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
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
    
    private func applyServerChanges(
        _ response: SyncBatchResponse,
        context: ModelContext,
        ownerID: String
    ) async throws {
        // 1. Procesar Kits
        for kitDTO in response.kits {
            if let id = kitDTO.id {
                // Buscar existente
                let descriptor = FetchDescriptor<GoalEntity>(
                    predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
                )
                let existing = try context.fetch(descriptor).first
                
                if let existing {
                    if kitDTO.deleted {
                        context.delete(existing)
                    } else {
                        existing.update(from: kitDTO)
                    }
                } else if !kitDTO.deleted {
                    let newGoal = GoalEntity(fromSync: kitDTO, ownerID: ownerID)
                    context.insert(newGoal)
                }
            }
        }
        
        // Guardar cambios de Kits para que los Steps puedan encontrar sus padres
        try context.save()
        
        // 2. Procesar Steps
        for stepDTO in response.steps {
            if let id = stepDTO.id {
                let descriptor = FetchDescriptor<StepEntity>(
                    predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
                )
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
                    let goalDescriptor = FetchDescriptor<GoalEntity>(
                        predicate: #Predicate { $0.id == kitId && $0.ownerID == ownerID }
                    )
                    if let parent = try context.fetch(goalDescriptor).first {
                        let newStep = StepEntity(
                            fromSync: stepDTO,
                            goal: parent,
                            ownerID: ownerID
                        )
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

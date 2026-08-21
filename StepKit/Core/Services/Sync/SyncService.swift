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
            guard let ownerID else { return nil }
            return syncCursor(for: ownerID)
        }
        set {
            guard let ownerID else { return }
            setSyncCursor(newValue, for: ownerID)
        }
    }
    
    private let authManager: AuthManager
    private let networkService: any SyncNetworkServicing
    private let preferences: UserDefaults
    private let now: @MainActor () -> Date
    private var modelContext: ModelContext?

    private var ownerID: String? {
        guard let id = authManager.currentUser?.id, !id.isEmpty else { return nil }
        return id
    }

    // MARK: - Init
    
    init(
        authManager: AuthManager,
        environment: AppEnvironment? = nil,
        networkService: (any SyncNetworkServicing)? = nil,
        preferences: UserDefaults = .standard,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.authManager = authManager
        self.preferences = preferences
        self.now = now
        let environment = environment ?? .current
        let httpClient = HTTPClient()
        self.networkService = networkService
            ?? SyncNetworkService(client: httpClient, baseURL: environment.apiBaseURL)
    }
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Public API
    
    /// Ejecuta sync si ha pasado el intervalo mínimo
    func syncIfNeeded(minInterval: TimeInterval) async {
        guard needsSync(minInterval: minInterval) else { return }
        try? await syncAll()
    }

    /// Consulta síncrona usada por `SyncManager` para que también los eventos
    /// de foreground pasen por su cola serializada.
    func needsSync(minInterval: TimeInterval) -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return now().timeIntervalSince(lastSync) > minInterval
    }
    
    /// Ejecuta una sincronización completa
    func syncAll() async throws {
        guard !isSyncing else { return }
        guard let context = modelContext else { return }
        guard let token = authManager.token else { return }
        guard let ownerID else { return }
        let previousCursor = syncCursor(for: ownerID)
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            // Este límite se captura antes de construir/enviar el batch. Una
            // mutación que ocurra mientras la red está suspendida tendrá un
            // `updatedAt` posterior y deberá entrar en la siguiente pasada.
            let cutoff = now()

            // 1. Recopilar cambios locales
            let request = try fetchLocalChanges(
                context: context,
                ownerID: ownerID,
                after: previousCursor,
                through: cutoff
            )
            
            // 2. Enviar al servidor
            let response = try await networkService.syncBatch(request, token: token)

            // Una respuesta de A no puede aplicarse ni avanzar el cursor si el
            // usuario cerró sesión o cambió a B durante la espera de red.
            guard self.ownerID == ownerID, authManager.token == token else {
                throw SyncServiceError.authenticationChanged
            }
            
            // 3. Aplicar cambios del servidor
            try applyServerChanges(
                response,
                context: context,
                ownerID: ownerID,
                preservingChangesAfter: cutoff
            )
            
            // 4. Avanzar solo hasta el límite cubierto por este request. Nunca
            // hasta la hora de respuesta, que podría saltarse cambios locales.
            setSyncCursor(cutoff, for: ownerID)
            
        } catch {
            #if DEBUG
            NetworkDiagnostics.logError(error, operation: "Sync")
            #endif
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchLocalChanges(
        context: ModelContext,
        ownerID: String,
        after previousCursor: Date?,
        through cutoff: Date
    ) throws -> SyncBatchRequest {
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
        
        if let previousCursor {
            kitsDTOs = allGoals
                .filter { $0.updatedAt > previousCursor && $0.updatedAt <= cutoff }
                .map { $0.toSyncDTO() }
            
            stepsDTOs = allSteps
                .filter { $0.updatedAt > previousCursor && $0.updatedAt <= cutoff }
                .map { $0.toSyncDTO() }
        } else {
            kitsDTOs = allGoals
                .filter { $0.updatedAt <= cutoff }
                .map { $0.toSyncDTO() }
            stepsDTOs = allSteps
                .filter { $0.updatedAt <= cutoff }
                .map { $0.toSyncDTO() }
        }
        
        return SyncBatchRequest(kits: kitsDTOs, steps: stepsDTOs)
    }
    
    private func applyServerChanges(
        _ response: SyncBatchResponse,
        context: ModelContext,
        ownerID: String,
        preservingChangesAfter cutoff: Date
    ) throws {
        // 1. Procesar Kits
        for kitDTO in response.kits {
            if let id = kitDTO.id {
                // Buscar existente
                let descriptor = FetchDescriptor<GoalEntity>(
                    predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
                )
                let existing = try context.fetch(descriptor).first
                
                if let existing {
                    // El snapshot se calculó a partir del estado enviado antes
                    // del cutoff. No puede sobrescribir una edición posterior.
                    guard existing.updatedAt <= cutoff else { continue }

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
                    guard existing.updatedAt <= cutoff else { continue }

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
                        #if DEBUG
                        print("⚠️ Orphaned step received: id=\(id), kit=\(kitId)")
                        #endif
                    }
                }
            }
        }
        
        try context.save()
    }

    private func syncCursor(for ownerID: String) -> Date? {
        preferences.object(forKey: syncCursorKey(for: ownerID)) as? Date
    }

    private func setSyncCursor(_ date: Date?, for ownerID: String) {
        preferences.set(date, forKey: syncCursorKey(for: ownerID))
    }

    private func syncCursorKey(for ownerID: String) -> String {
        "stepkit.lastSyncDate.\(ownerID)"
    }
}

private enum SyncServiceError: Error {
    case authenticationChanged
}

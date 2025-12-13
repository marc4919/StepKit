//
//  SyncService.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 10/12/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Errores específicos de sincronización
enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case noModelContext
    case networkError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No autenticado. Inicia sesión para sincronizar."
        case .noModelContext:
            return "Contexto de datos no disponible."
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Error del servidor (\(code)): \(message)"
        }
    }
}

/// Servicio de sincronización bidireccional con el backend
@Observable
@MainActor
final class SyncService {
    // MARK: - Dependencies

    private let apiClient: APIClient
    private let authManager: AuthManager
    private var modelContext: ModelContext?

    // MARK: - State

    private(set) var isSyncing: Bool = false
    private(set) var lastError: Error?

    // Persistir lastSyncDate en UserDefaults
    private static let lastSyncDateKey = "lastSyncDate"

    var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.lastSyncDateKey)
        }
    }

    // MARK: - Init

    init(apiClient: APIClient? = nil, authManager: AuthManager) {
        self.apiClient = apiClient ?? APIClient()
        self.authManager = authManager
    }

    /// Configura el contexto de SwiftData (llamar desde la app)
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Sincroniza todos los datos locales con el servidor
    /// Solo disponible para usuarios Premium
    func syncAll() async throws {
        guard !isSyncing else {
            #if DEBUG
            print("🔄 Sync already in progress, skipping...")
            #endif
            return
        }

        guard authManager.isAuthenticated, let token = authManager.token else {
            throw SyncError.notAuthenticated
        }

        // Sync is only available for premium users
        guard authManager.currentUser?.isPremium == true else {
            #if DEBUG
            print("🔒 Sync disabled for free users")
            #endif
            return
        }

        guard let context = modelContext else {
            throw SyncError.noModelContext
        }

        isSyncing = true
        lastError = nil

        defer {
            isSyncing = false
        }

        #if DEBUG
        print("🔄 Starting full sync...")
        #endif

        do {
            // 1. Recopilar datos locales
            let localKits = try fetchLocalKits(from: context)
            let localSteps = try fetchLocalSteps(from: context)

            #if DEBUG
            print("📤 Sending \(localKits.count) kits and \(localSteps.count) steps to server")
            #endif

            // 2. Construir request
            let request = SyncBatchRequest(
                kits: localKits.map { $0.toSyncDTO() },
                steps: localSteps.map { $0.toSyncDTO() }
            )

            // 3. Enviar al servidor
            let response = try await apiClient.syncBatch(request, token: token)

            #if DEBUG
            print("📥 Received \(response.kits.count) kits and \(response.steps.count) steps from server")
            if !response.conflicts.isEmpty {
                print("⚠️ Conflicts: \(response.conflicts.count)")
                response.conflicts.forEach { print("   - \($0.entityType) \($0.entityId): \($0.reason)") }
            }
            #endif

            // 4. Aplicar cambios del servidor
            try applyServerResponse(response, to: context)

            // 5. Guardar contexto
            try context.save()

            lastSyncDate = Date()

            #if DEBUG
            print("✅ Sync completed successfully at \(lastSyncDate!)")
            #endif

        } catch let error as APIError {
            lastError = error
            #if DEBUG
            print("❌ Sync API error: \(error)")
            #endif
            throw mapAPIError(error)
        } catch {
            lastError = error
            #if DEBUG
            print("❌ Sync error: \(error)")
            #endif
            throw SyncError.networkError(error)
        }
    }

    /// Sincroniza si ha pasado suficiente tiempo desde la última sincronización
    func syncIfNeeded(minInterval: TimeInterval = 60) async {
        guard let lastSync = lastSyncDate else {
            // Nunca se ha sincronizado
            try? await syncAll()
            return
        }

        let elapsed = Date().timeIntervalSince(lastSync)
        if elapsed >= minInterval {
            try? await syncAll()
        }
    }

    // MARK: - Private Methods

    private func fetchLocalKits(from context: ModelContext) throws -> [GoalEntity] {
        let descriptor = FetchDescriptor<GoalEntity>()
        return try context.fetch(descriptor)
    }

    private func fetchLocalSteps(from context: ModelContext) throws -> [StepEntity] {
        let descriptor = FetchDescriptor<StepEntity>()
        return try context.fetch(descriptor)
    }

    private func applyServerResponse(_ response: SyncBatchResponse, to context: ModelContext) throws {
        // Crear diccionarios para búsqueda rápida
        let existingKits = try fetchLocalKits(from: context)
        let existingSteps = try fetchLocalSteps(from: context)

        var kitsById: [UUID: GoalEntity] = [:]
        for kit in existingKits {
            kitsById[kit.id] = kit
        }

        var stepsById: [UUID: StepEntity] = [:]
        for step in existingSteps {
            stepsById[step.id] = step
        }

        // Procesar Kits del servidor
        for kitDTO in response.kits {
            guard let kitId = kitDTO.id else { continue }

            if let existingKit = kitsById[kitId] {
                // Caso especial: si el cliente tiene un delete local más reciente, NO restaurar
                if existingKit.isDeleted && !kitDTO.deleted {
                    let localDeleteTime = existingKit.deletedAt ?? existingKit.updatedAt
                    if localDeleteTime > kitDTO.updatedAt {
                        #if DEBUG
                        print("🛡️ Kit \(kitId): keeping local delete (local delete at \(localDeleteTime) > server update at \(kitDTO.updatedAt))")
                        #endif
                        continue
                    }
                }

                // LWW: Solo actualizar si el servidor tiene una versión más reciente
                let serverIsNewer = kitDTO.version > existingKit.version ||
                    (kitDTO.version == existingKit.version && kitDTO.updatedAt > existingKit.updatedAt)

                if serverIsNewer {
                    existingKit.update(from: kitDTO)
                    #if DEBUG
                    print("📝 Kit \(kitId): server is newer (v\(kitDTO.version) vs v\(existingKit.version))")
                    #endif
                } else {
                    #if DEBUG
                    print("🛡️ Kit \(kitId): keeping local (v\(existingKit.version) vs server v\(kitDTO.version))")
                    #endif
                }
            } else {
                // Crear nuevo kit (solo si no está eliminado en el servidor)
                if !kitDTO.deleted {
                    // Verificar si este kit es de una sesión cancelada
                    if shouldAutoDeleteOrphanKit(kitDTO) {
                        // Crear como eliminado para que el servidor lo elimine
                        let deletedKit = GoalEntity(fromSync: kitDTO)
                        deletedKit.markAsDeleted(at: Date())
                        context.insert(deletedKit)
                        kitsById[kitId] = deletedKit
                        #if DEBUG
                        print("🗑️ Auto-deleted orphan kit from cancelled session: \(kitId)")
                        #endif
                    } else {
                        let newKit = GoalEntity(fromSync: kitDTO)
                        context.insert(newKit)
                        kitsById[kitId] = newKit
                    }
                }
            }
        }

        // Limpiar el flag de sesión cancelada después de procesar
        clearCancelledSessionFlag()

        // Procesar Steps del servidor
        for stepDTO in response.steps {
            guard let stepId = stepDTO.id else { continue }

            if let existingStep = stepsById[stepId] {
                // LWW: Solo actualizar si el servidor tiene una versión más reciente
                let serverUpdatedAt = stepDTO.updatedAt ?? Date.distantPast
                let serverIsNewer = serverUpdatedAt > existingStep.updatedAt

                if serverIsNewer {
                    existingStep.update(from: stepDTO)
                    #if DEBUG
                    print("📝 Step \(stepId): server is newer")
                    #endif
                } else {
                    #if DEBUG
                    print("🛡️ Step \(stepId): keeping local")
                    #endif
                }
            } else {
                // Crear nuevo step (necesita el goal parent)
                if let parentKit = kitsById[stepDTO.kitId] {
                    let newStep = StepEntity(fromSync: stepDTO, goal: parentKit)
                    context.insert(newStep)
                    parentKit.steps.append(newStep)
                }
            }
        }

        // No marcar locales como eliminados si el servidor no los tiene
        // El servidor es autoritativo solo si devuelve explícitamente deleted=true
        // Esto evita que kits/steps recién creados localmente se marquen como eliminados
    }

    private func mapAPIError(_ error: APIError) -> SyncError {
        switch error {
        case .notAuthenticated:
            return .notAuthenticated
        case .serverError(let code, let message):
            return .serverError(code, message)
        default:
            return .networkError(error)
        }
    }

    // MARK: - Orphan Kit Detection

    /// Determina si un kit del servidor debe ser auto-eliminado porque pertenece a una sesión cancelada
    private func shouldAutoDeleteOrphanKit(_ kitDTO: KitSyncDTO) -> Bool {
        guard let cancelledAt = UserDefaults.standard.object(forKey: "lastCancelledKitCreationAt") as? Date else {
            return false
        }

        // Solo aplicar si la cancelación fue en los últimos 5 minutos
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        guard cancelledAt > fiveMinutesAgo else {
            return false
        }

        // Verificar si el kit se creó cerca del tiempo de cancelación (dentro de 2 minutos)
        let kitCreatedAt = kitDTO.createdAt ?? Date.distantPast
        let timeDiff = abs(kitCreatedAt.timeIntervalSince(cancelledAt))

        if timeDiff < 120 {
            #if DEBUG
            print("🔍 Detected orphan kit: created at \(kitCreatedAt), session cancelled at \(cancelledAt), diff: \(timeDiff)s")
            #endif
            return true
        }

        return false
    }

    /// Limpia el flag de sesión cancelada
    private func clearCancelledSessionFlag() {
        if let cancelledAt = UserDefaults.standard.object(forKey: "lastCancelledKitCreationAt") as? Date {
            // Solo limpiar si han pasado más de 5 minutos
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            if cancelledAt < fiveMinutesAgo {
                UserDefaults.standard.removeObject(forKey: "lastCancelledKitCreationAt")
                #if DEBUG
                print("🧹 Cleared expired cancelled session flag")
                #endif
            }
        }
    }
}

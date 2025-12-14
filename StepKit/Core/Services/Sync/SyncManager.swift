//
//  SyncManager.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 10/12/25.
//

import Foundation
import SwiftUI

/// Coordinador de sincronización que decide cuándo ejecutar sync
@Observable
@MainActor
final class SyncManager {
    // MARK: - Dependencies

    private let syncService: SyncService

    // MARK: - State

    private var syncTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var periodicSyncTask: Task<Void, Never>?

    /// Indica si hay una sincronización en curso
    var isSyncing: Bool {
        syncService.isSyncing
    }

    /// Última fecha de sincronización exitosa
    var lastSyncDate: Date? {
        syncService.lastSyncDate
    }

    // MARK: - Configuration

    /// Intervalo mínimo entre sincronizaciones automáticas (segundos)
    private let minSyncInterval: TimeInterval = 60

    /// Tiempo de debounce para agrupar cambios rápidos (milisegundos)
    private let debounceDelay: Duration = .milliseconds(500)

    /// Intervalo de sincronización periódica (segundos)
    private let periodicSyncInterval: TimeInterval = 300  // 5 minutos

    // MARK: - Init

    init(syncService: SyncService) {
        self.syncService = syncService
    }

    // MARK: - Public API

    /// Inicia la sincronización automática (llamar al autenticarse)
    func startAutoSync() {
        #if DEBUG
        print("🚀 SyncManager: Starting auto sync")
        #endif

        // Sincronizar inmediatamente
        triggerSync()

        // Iniciar sincronización periódica
        startPeriodicSync()
    }

    /// Detiene la sincronización automática (llamar al cerrar sesión)
    func stopAutoSync() {
        #if DEBUG
        print("🛑 SyncManager: Stopping auto sync")
        #endif

        syncTask?.cancel()
        syncTask = nil

        debounceTask?.cancel()
        debounceTask = nil

        periodicSyncTask?.cancel()
        periodicSyncTask = nil
    }

    /// Dispara una sincronización con debounce
    /// Usar después de modificar datos locales
    func triggerSync() {
        // Cancelar debounce anterior si existe
        debounceTask?.cancel()

        debounceTask = Task {
            // Esperar el tiempo de debounce
            try? await Task.sleep(for: .milliseconds(500))

            // Verificar que no fue cancelado
            guard !Task.isCancelled else { return }

            await executeSync()
        }
    }

    /// Maneja el evento de app entrando a foreground
    func handleAppForeground() {
        #if DEBUG
        print("📱 SyncManager: App entered foreground")
        #endif

        // Sincronizar si ha pasado el intervalo mínimo
        Task {
            await syncService.syncIfNeeded(minInterval: minSyncInterval)
        }
    }

    /// Maneja cambios de datos (llamar después de crear/editar/eliminar)
    func handleDataChange() {
        #if DEBUG
        print("📡 SyncManager: handleDataChange called, triggering sync...")
        #endif
        triggerSync()
    }

    /// Fuerza una sincronización inmediata (sin debounce)
    func forceSync() async {
        await executeSync()
    }

    /// Cancela cualquier sync en curso y espera a que termine
    /// Útil antes de operaciones críticas como eliminar
    func cancelAndWaitForSync() async {
        // Cancelar tareas pendientes
        debounceTask?.cancel()
        debounceTask = nil

        // Esperar a que termine el sync en curso si hay uno
        if let task = syncTask {
            await task.value
        }
    }

    // MARK: - Private Methods

    private func executeSync() async {
        // Evitar múltiples syncs simultáneos
        guard syncTask == nil else {
            #if DEBUG
            print("⏳ SyncManager: Sync already running, queuing...")
            #endif
            return
        }

        syncTask = Task {
            do {
                #if DEBUG
                print("🔄 SyncManager: Starting sync...")
                #endif
                try await syncService.syncAll()
                #if DEBUG
                print("✅ SyncManager: Sync completed successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ SyncManager: Sync failed - \(error.localizedDescription)")
                #endif
                // Errores se manejan silenciosamente según los requisitos
            }
        }

        await syncTask?.value
        syncTask = nil
    }

    private func startPeriodicSync() {
        periodicSyncTask?.cancel()

        periodicSyncTask = Task {
            while !Task.isCancelled {
                // Esperar el intervalo
                try? await Task.sleep(for: .seconds(300))

                // Verificar que no fue cancelado
                guard !Task.isCancelled else { break }

                #if DEBUG
                print("⏰ SyncManager: Periodic sync triggered")
                #endif

                await executeSync()
            }
        }
    }
}

// MARK: - Environment Key

private struct SyncManagerKey: EnvironmentKey {
    static let defaultValue: SyncManager? = nil
}

extension EnvironmentValues {
    var syncManager: SyncManager? {
        get { self[SyncManagerKey.self] }
        set { self[SyncManagerKey.self] = newValue }
    }
}

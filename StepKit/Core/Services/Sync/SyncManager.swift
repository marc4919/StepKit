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
    private var syncRequested = false

    /// Permanece activo durante toda la operación observable, incluidas las
    /// pasadas que se hayan solicitado mientras un request estaba suspendido.
    private(set) var isSyncing = false

    /// Última fecha de sincronización exitosa
    var lastSyncDate: Date? {
        syncService.lastSyncDate
    }

    #if DEBUG
    /// Contador por proceso para que una prueba E2E pueda distinguir el cursor
    /// persistido de una sincronización realmente completada en este arranque.
    private(set) var completedSyncCount = 0
    #endif

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
        syncRequested = false

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

        // También este origen pasa por la misma cola: ninguna petición puede
        // competir con otra ni perderse por el guard interno del servicio.
        Task { [weak self] in
            guard let self,
                  syncService.needsSync(minInterval: minSyncInterval) else {
                return
            }
            await executeSync()
        }
    }

    /// Maneja cambios de datos (llamar después de crear/editar/eliminar)
    func handleDataChange() {
        NotificationService.shared.refreshStepReminders()
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
        // Registrar primero la intención. Si ya hay una operación en curso, su
        // bucle hará otra pasada y este llamador esperará a que termine todo el
        // drenaje, no solo el request que encontró activo.
        syncRequested = true

        if let syncTask {
            #if DEBUG
            print("⏳ SyncManager: Sync already running, queuing...")
            #endif
            await syncTask.value
            return
        }

        isSyncing = true
        let task = Task { [weak self] in
            guard let self else { return }
            await drainSyncRequests()
        }
        syncTask = task
        await task.value
    }

    private func drainSyncRequests() async {
        defer {
            syncTask = nil
            isSyncing = false
        }

        while syncRequested, !Task.isCancelled {
            syncRequested = false

            do {
                #if DEBUG
                print("🔄 SyncManager: Starting sync...")
                #endif
                try await syncService.syncAll()
                // Lo que llega de otros dispositivos (fechas, pasos completados) cambia los avisos.
                NotificationService.shared.refreshStepReminders()
                #if DEBUG
                completedSyncCount += 1
                print("✅ SyncManager: Sync completed successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ SyncManager: Sync failed")
                #endif
                // El siguiente trigger puede reintentar; no se expone contenido
                // del error ni se avanza el cursor en la pasada fallida.
            }
        }
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

extension EnvironmentValues {
    @Entry var syncManager: SyncManager? = nil
}

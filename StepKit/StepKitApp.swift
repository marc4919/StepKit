//
//  StepKitApp.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 6/10/25.
//

import SwiftUI
import SwiftData
import TipKit
import UserNotifications

@main
struct StepKitApp: App {
    @State private var authManager = AuthManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    // Sync
    @State private var syncService: SyncService?
    @State private var syncManager: SyncManager?

    init() {
        try? Tips.configure([
            .displayFrequency(.immediate)
        ])
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GoalEntity.self,
            StepEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .fullScreenCover(isPresented: $showOnboarding) {
                            OnboardingView {
                                showOnboarding = false
                                hasCompletedOnboarding = true
                            }
                            .interactiveDismissDisabled()
                        }
                        .onAppear {
                            if !hasCompletedOnboarding {
                                showOnboarding = true
                            }
                        }
                        .task {
                            // Solicitar permisos de notificación y verificar estado
                            await NotificationService.shared.checkAuthorizationStatus()
                            if !NotificationService.shared.isAuthorized {
                                await NotificationService.shared.requestAuthorization()
                            }

                            // Inicializar sync si no existe
                            if syncService == nil {
                                let service = SyncService(authManager: authManager)
                                service.configure(with: sharedModelContainer.mainContext)
                                syncService = service

                                let manager = SyncManager(syncService: service)
                                syncManager = manager
                                manager.startAutoSync()
                            }
                        }
                } else {
                    SignInView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncManager?.handleAppForeground()
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if !isAuthenticated {
                    // Usuario cerró sesión, detener sync
                    syncManager?.stopAutoSync()
                    syncService = nil
                    syncManager = nil
                }
            }
        }
        .environment(authManager)
        .environment(\.apiClient, APIClient())
        .environment(\.syncManager, syncManager)
        .modelContainer(sharedModelContainer)
    }
}

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
    @State private var aiConsentManager = AIConsentManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showAIConsent = false
    @Environment(\.scenePhase) private var scenePhase
    private let apiClient = APIClient()

    // Sync
    @State private var syncService: SyncService?
    @State private var syncManager: SyncManager?

    init() {
        try? Tips.configure([
            .displayFrequency(.immediate)
        ])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isRestoringSession {
                    ProgressView("Validando sesión…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authManager.isAuthenticated {
                    ContentView()
                        .fullScreenCover(isPresented: $showOnboarding) {
                            OnboardingView {
                                showOnboarding = false
                                hasCompletedOnboarding = true
                            }
                            .interactiveDismissDisabled()
                        }
                        .fullScreenCover(isPresented: $showAIConsent) {
                            AIConsentView {
                                showAIConsent = false
                            }
                            .interactiveDismissDisabled()
                        }
                        .onAppear {
                            if !hasCompletedOnboarding {
                                showOnboarding = true
                            } else if !aiConsentManager.hasConsent {
                                // Si completó onboarding pero no tiene consentimiento, mostrarlo
                                showAIConsent = true
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
                                service.configure(with: PersistenceController.shared.container.mainContext)
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
            .task {
                if let restoredUser = await authManager.validateStoredSession(using: apiClient) {
                    do {
                        try PersistenceController.shared.claimLegacyData(for: restoredUser.id)
                    } catch {
                        #if DEBUG
                        print("Could not claim legacy local data: \(error)")
                        #endif
                    }
                    authManager.completeStoredSessionRestore(with: restoredUser)
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
        .environment(aiConsentManager)
        .environment(\.apiClient, apiClient)
        .environment(\.syncManager, syncManager)
        .modelContainer(PersistenceController.shared.container)
    }
}

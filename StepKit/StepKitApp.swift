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
    @State private var didBootstrapAuthentication = false
    @Environment(\.scenePhase) private var scenePhase
    private let appEnvironment: AppEnvironment
    private let apiClient: APIClient
    #if DEBUG
    private let e2eAuthenticationMode: E2EAuthenticationLaunchMode
    private let shouldSuppressNotificationsForE2E: Bool
    #endif

    // Sync
    @State private var syncService: SyncService?
    @State private var syncManager: SyncManager?

    init() {
        let appEnvironment = AppEnvironment.current
        self.appEnvironment = appEnvironment
        self.apiClient = APIClient(environment: appEnvironment)

        #if DEBUG
        let launchArguments = ProcessInfo.processInfo.arguments
        self.e2eAuthenticationMode = E2ELaunchConfiguration
            .authenticationMode(arguments: launchArguments)
        self.shouldSuppressNotificationsForE2E = E2ELaunchConfiguration
            .shouldSuppressNotifications(arguments: launchArguments)
        NetworkDiagnostics.logEnvironment(appEnvironment)
        #endif

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
                            if shouldRequestNotifications {
                                await NotificationService.shared.checkAuthorizationStatus()
                                if !NotificationService.shared.isAuthorized {
                                    await NotificationService.shared.requestAuthorization()
                                }
                            }

                            // Inicializar sync si no existe
                            if syncService == nil {
                                let service = SyncService(
                                    authManager: authManager,
                                    environment: appEnvironment
                                )
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
                await bootstrapAuthenticationIfNeeded()
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

    @MainActor
    private func bootstrapAuthenticationIfNeeded() async {
        guard !didBootstrapAuthentication else { return }
        didBootstrapAuthentication = true

        #if DEBUG
        switch e2eAuthenticationMode {
        case .invalid:
            // Una combinación contradictoria nunca restaura una sesión previa
            // ni activa un bypass de autenticación.
            authManager.signOut()
            return

        case let .invalidStoredSession(shouldResetLocalState):
            do {
                if shouldResetLocalState {
                    try E2ELocalStateResetter().reset(authentication: authManager)
                }
                try authManager.seedInvalidStoredSessionForE2E()
            } catch {
                authManager.signOut()
                NetworkDiagnostics.logError(error, operation: "Invalid stored E2E session")
                return
            }

        case let .account(account, shouldResetLocalState):
            if shouldResetLocalState {
                do {
                    try E2ELocalStateResetter().reset(authentication: authManager)
                } catch {
                    authManager.signOut()
                    NetworkDiagnostics.logError(error, operation: "Local E2E reset")
                    return
                }
            }

            do {
                let response = try await apiClient.signInForE2E(
                    account: account
                )
                // La sesión pasa por el mismo AuthManager, Keychain y recuperación
                // de ownership que Sign in with Apple.
                authManager.saveAuth(token: response.token, user: response.user)
            } catch {
                authManager.signOut()
                NetworkDiagnostics.logError(error, operation: "E2E authentication")
            }
            return

        case .normal:
            break
        }
        #endif

        if let restoredUser = await authManager.validateStoredSession(using: apiClient) {
            authManager.completeStoredSessionRestore(with: restoredUser)
        }
    }

    private var shouldRequestNotifications: Bool {
        #if DEBUG
        !shouldSuppressNotificationsForE2E
        #else
        true
        #endif
    }
}

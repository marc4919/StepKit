//
//  AuthManager.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation
import Observation

/// Gestiona el estado de autenticación de la app usando @Observable (Swift 6)
@MainActor
@Observable
final class AuthManager: AuthManaging {
    private(set) var sessionID = UUID()
    var isAuthenticated = false
    var isRestoringSession = false
    var currentUser: UserInfo?
    
    /// Nombre a mostrar en el perfil (puede venir de Apple o de la API)
    var displayName: String?
    
    private let tokenKey = "stepkit_jwt_token"
    private let userKey = "stepkit_user_info"
    private let profileNameKey = "stepkit_profile_display_name"
    private let forcedSignOutKey = "stepkit.authentication.forcedSignOut"
    private let keychain: any KeychainStoring
    private let legacyRecovery: LegacyOwnershipRecovery
    private let preferences: UserDefaults
    
    init(
        keychain: (any KeychainStoring)? = nil,
        legacyRecovery: LegacyOwnershipRecovery? = nil,
        preferences: UserDefaults = .standard
    ) {
        let keychain = keychain ?? KeychainManager.shared
        self.keychain = keychain
        self.preferences = preferences
        self.legacyRecovery = legacyRecovery ?? LegacyOwnershipRecovery(
            keychain: keychain,
            legacyData: PersistenceController.shared
        )
        // Las credenciales almacenadas no se consideran una sesión válida hasta
        // que el backend las confirme mediante GET /me.
        loadStoredAuth()
    }
    
    // MARK: - Token Management
    
    /// Token JWT actual. Se guarda automáticamente en Keychain cuando se asigna
    var token: String? {
        get {
            guard !preferences.bool(forKey: forcedSignOutKey) else { return nil }
            return try? keychain.getString(forKey: tokenKey)
        }
        set {
            if let token = newValue {
                do {
                    try keychain.saveString(token, forKey: tokenKey)
                    preferences.removeObject(forKey: forcedSignOutKey)
                    sessionID = UUID()
                } catch {
                    #if DEBUG
                    print("Could not update stored authentication token")
                    #endif
                }
            } else {
                invalidateStoredSession()
                isAuthenticated = false
                currentUser = nil
                displayName = nil
            }
        }
    }
    
    // MARK: - Auth Methods
    
    /// Guarda la autenticación después de un login exitoso
    /// - Parameters:
    ///   - token: El token JWT recibido del backend
    ///   - user: La información del usuario
    func saveAuth(token: String, user: UserInfo) {
        sessionID = UUID()
        prepareLegacyRecoveryForStoredSessionIfNeeded()

        do {
            // El usuario se escribe primero y el token actúa como commit marker:
            // `loadStoredAuth` nunca restaura una sesión sin token. Keychain no
            // ofrece una transacción multi-item, por lo que cualquier parcial
            // se limpia además antes de fallar cerrado.
            try keychain.save(user, forKey: userKey)
            try keychain.saveString(token, forKey: tokenKey)
            preferences.removeObject(forKey: forcedSignOutKey)
        } catch {
            invalidateStoredSession()
            currentUser = nil
            isRestoringSession = false
            isAuthenticated = false
            #if DEBUG
            print("Could not persist authentication session")
            #endif
            return
        }

        // Reclamar datos legacy también ocurre después de persistir la sesión:
        // un fallo local de credenciales no debe producir efectos de ownership.
        recoverLegacyDataIfAuthorized(for: user.id)

        self.currentUser = user
        self.isRestoringSession = false
        self.isAuthenticated = true
    }
    
    /// Actualiza la información del usuario en memoria y persistencia
    /// - Parameter user: Nueva información del usuario
    func updateUser(_ user: UserInfo) {
        self.currentUser = user
        
        // Actualizar persistencia
        do {
            try keychain.save(user, forKey: userKey)
        } catch {
            #if DEBUG
            print("Could not update stored user information")
            #endif
        }
    }
    
    /// Cierra sesión y limpia todos los datos de autenticación
    func signOut() {
        invalidateStoredSession()
        currentUser = nil
        displayName = nil
        isAuthenticated = false
        isRestoringSession = false
    }

    /// Valida las credenciales persistidas sin activar todavía la sesión local.
    /// El llamador puede migrar de forma segura datos legacy antes de mostrar contenido.
    func validateStoredSession(using apiClient: any APIClientProtocol) async -> UserInfo? {
        guard isRestoringSession, let storedToken = token else {
            isRestoringSession = false
            return nil
        }

        // El ID local se ancla antes de que una validación fallida borre las
        // credenciales. No concede acceso: solo permite que esa misma identidad
        // reclame posteriormente los datos sin dueño.
        prepareLegacyRecoveryForStoredSessionIfNeeded()

        do {
            return try await apiClient.getUserProfile(token: storedToken)
        } catch {
            // Fallo cerrado: una credencial que el servidor no ha confirmado no
            // concede acceso a datos locales ni remotos.
            signOut()
            return nil
        }
    }

    /// Activa una sesión previamente validada por el servidor.
    func completeStoredSessionRestore(with user: UserInfo) {
        sessionID = UUID()
        recoverLegacyDataIfAuthorized(for: user.id)
        updateUser(user)
        isRestoringSession = false
        isAuthenticated = true
    }
    
    /// Actualiza el nombre a mostrar y lo persiste.
    /// No depende de la API: se puede alimentar con datos de Apple o de otros orígenes.
    func updateDisplayName(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        displayName = name
        do {
            try keychain.saveString(name, forKey: profileNameKey)
        } catch {
            #if DEBUG
            print("Could not update stored profile name")
            #endif
        }
    }

    #if DEBUG
    /// Elimina solo credenciales y marcadores propios de StepKit. Se usa junto
    /// al reset de SwiftData/UserDefaults para preparar lanzamientos UI E2E.
    func resetAuthenticationForE2E() throws {
        sessionID = UUID()
        try keychain.delete(forKey: tokenKey)
        try keychain.delete(forKey: userKey)
        try keychain.delete(forKey: profileNameKey)
        try legacyRecovery.resetPendingClaimForE2E()
        preferences.removeObject(forKey: forcedSignOutKey)

        isAuthenticated = false
        isRestoringSession = false
        currentUser = nil
        displayName = nil
    }

    /// Prepara el mismo estado que deja una versión anterior de la app con un
    /// JWT caducado. La restauración ordinaria deberá validarlo con GET /me y
    /// cerrar la sesión al recibir el rechazo del servidor.
    func seedInvalidStoredSessionForE2E() throws {
        sessionID = UUID()
        let invalidUser = UserInfo(
            id: "invalid-stored-session-owner",
            tier: "free",
            monthlyTokensUsed: 0,
            monthlyTokenQuota: 1_000
        )
        try keychain.save(invalidUser, forKey: userKey)
        try keychain.saveString("invalid-stored-session-token", forKey: tokenKey)
        preferences.removeObject(forKey: forcedSignOutKey)

        currentUser = invalidUser
        isAuthenticated = false
        isRestoringSession = true
    }
    #endif
    
    // MARK: - Private Helpers

    private func prepareLegacyRecoveryForStoredSessionIfNeeded() {
        guard isRestoringSession else { return }
        do {
            _ = try legacyRecovery.prepareClaimIfNeeded(previousOwnerID: currentUser?.id)
        } catch {
            #if DEBUG
            print("Could not prepare legacy ownership recovery")
            #endif
        }
    }

    private func recoverLegacyDataIfAuthorized(for ownerID: String) {
        do {
            _ = try legacyRecovery.claimIfAuthorized(authenticatedOwnerID: ownerID)
        } catch {
            // La sesión puede continuar, pero los datos legacy permanecen ocultos
            // y el marcador se conserva para reintentar en el siguiente login.
            #if DEBUG
            print("Could not complete legacy ownership recovery")
            #endif
        }
    }

    private func invalidateStoredSession() {
        sessionID = UUID()
        let tokenWasInvalidated: Bool
        do {
            try keychain.delete(forKey: tokenKey)
            tokenWasInvalidated = true
        } catch {
            // Si borrar falla, un valor vacío sigue siendo un commit marker no
            // restaurable. Si también falla, el marcador local bloquea cualquier
            // lectura del token superviviente en este sandbox.
            do {
                try keychain.saveString("", forKey: tokenKey)
                tokenWasInvalidated = true
            } catch {
                tokenWasInvalidated = false
            }
        }

        if tokenWasInvalidated {
            preferences.removeObject(forKey: forcedSignOutKey)
        } else {
            preferences.set(true, forKey: forcedSignOutKey)
        }

        try? keychain.delete(forKey: userKey)
        try? keychain.delete(forKey: profileNameKey)
    }
    
    /// Carga la autenticación guardada del Keychain
    private func loadStoredAuth() {
        if preferences.bool(forKey: forcedSignOutKey) {
            // Reintenta la limpieza en cada arranque, pero nunca expone el token
            // mientras el commit de logout siga pendiente.
            invalidateStoredSession()
            isAuthenticated = false
            isRestoringSession = false
            currentUser = nil
            displayName = nil
            return
        }

        do {
            // Cargar token
            if let storedToken = try keychain.getString(forKey: tokenKey),
               !storedToken.isEmpty {
                isAuthenticated = false
                isRestoringSession = true
                
                // Cargar info del usuario si existe
                if let storedUser: UserInfo = try keychain.get(forKey: userKey) {
                    currentUser = storedUser
                }
                
                // Cargar nombre de perfil si existe
                if let storedName = try keychain.getString(forKey: profileNameKey),
                   !storedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    displayName = storedName
                }
            } else {
                isAuthenticated = false
                isRestoringSession = false
                currentUser = nil
                displayName = nil
            }
        } catch {
            #if DEBUG
            print("Could not load stored authentication")
            #endif
            isAuthenticated = false
            isRestoringSession = false
            currentUser = nil
            displayName = nil
        }
    }
}

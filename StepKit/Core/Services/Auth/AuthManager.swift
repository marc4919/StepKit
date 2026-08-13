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
    var isAuthenticated = false
    var isRestoringSession = false
    var currentUser: UserInfo?
    
    /// Nombre a mostrar en el perfil (puede venir de Apple o de la API)
    var displayName: String?
    
    private let tokenKey = "stepkit_jwt_token"
    private let userKey = "stepkit_user_info"
    private let profileNameKey = "stepkit_profile_display_name"
    private let keychain: any KeychainStoring
    
    init(keychain: (any KeychainStoring)? = nil) {
        self.keychain = keychain ?? KeychainManager.shared
        // Las credenciales almacenadas no se consideran una sesión válida hasta
        // que el backend las confirme mediante GET /me.
        loadStoredAuth()
    }
    
    // MARK: - Token Management
    
    /// Token JWT actual. Se guarda automáticamente en Keychain cuando se asigna
    var token: String? {
        get {
            try? keychain.getString(forKey: tokenKey)
        }
        set {
            do {
                if let token = newValue {
                    try keychain.saveString(token, forKey: tokenKey)
                } else {
                    try keychain.delete(forKey: tokenKey)
                    try keychain.delete(forKey: userKey)
                    try keychain.delete(forKey: profileNameKey)
                    isAuthenticated = false
                    currentUser = nil
                    displayName = nil
                }
            } catch {
                print("Error al guardar/eliminar token: \(error)")
            }
        }
    }
    
    // MARK: - Auth Methods
    
    /// Guarda la autenticación después de un login exitoso
    /// - Parameters:
    ///   - token: El token JWT recibido del backend
    ///   - user: La información del usuario
    func saveAuth(token: String, user: UserInfo) {
        self.token = token
        self.currentUser = user
        self.isRestoringSession = false
        self.isAuthenticated = true
        
        // Guardar también la info del usuario en Keychain
        do {
            try keychain.save(user, forKey: userKey)
        } catch {
            print("Error al guardar información del usuario: \(error)")
        }
    }
    
    /// Actualiza la información del usuario en memoria y persistencia
    /// - Parameter user: Nueva información del usuario
    func updateUser(_ user: UserInfo) {
        self.currentUser = user
        
        // Actualizar persistencia
        do {
            try keychain.save(user, forKey: userKey)
        } catch {
            print("Error al actualizar información del usuario: \(error)")
        }
    }
    
    /// Cierra sesión y limpia todos los datos de autenticación
    func signOut() {
        token = nil
        currentUser = nil
        displayName = nil
        isRestoringSession = false
        do {
            try keychain.delete(forKey: profileNameKey)
        } catch {
            print("Error al borrar el nombre de perfil: \(error)")
        }
    }

    /// Valida las credenciales persistidas sin activar todavía la sesión local.
    /// El llamador puede migrar de forma segura datos legacy antes de mostrar contenido.
    func validateStoredSession(using apiClient: any APIClientProtocol) async -> UserInfo? {
        guard isRestoringSession, let storedToken = token else {
            isRestoringSession = false
            return nil
        }

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
            print("Error al guardar el nombre de perfil: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Carga la autenticación guardada del Keychain
    private func loadStoredAuth() {
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
            print("Error al cargar autenticación almacenada: \(error)")
            isAuthenticated = false
            isRestoringSession = false
            currentUser = nil
            displayName = nil
        }
    }
}

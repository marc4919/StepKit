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
    var currentUser: UserInfo?
    
    /// Nombre a mostrar en el perfil (puede venir de Apple o de la API)
    var displayName: String?
    
    private let tokenKey = "stepkit_jwt_token"
    private let userKey = "stepkit_user_info"
    private let profileNameKey = "stepkit_profile_display_name"
    private let keychain: KeychainManager
    
    init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
        // Cargar token guardado al iniciar
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
                    isAuthenticated = true
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
        
        // Guardar también la info del usuario en Keychain
        do {
            try keychain.save(user, forKey: userKey)
        } catch {
            print("Error al guardar información del usuario: \(error)")
        }
    }
    
    /// Cierra sesión y limpia todos los datos de autenticación
    func signOut() {
        token = nil
        currentUser = nil
        displayName = nil
        do {
            try keychain.delete(forKey: profileNameKey)
        } catch {
            print("Error al borrar el nombre de perfil: \(error)")
        }
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
                isAuthenticated = true
                
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
                currentUser = nil
                displayName = nil
            }
        } catch {
            print("Error al cargar autenticación almacenada: \(error)")
            isAuthenticated = false
            currentUser = nil
            displayName = nil
        }
    }
}


#if DEBUG
//
//  MockAuthManager.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation
import Observation

/// Mock del AuthManager para tests y previews
/// Permite simular diferentes estados de autenticación sin usar Keychain real
@MainActor
@Observable
final class MockAuthManager: AuthManaging {
    private(set) var sessionID = UUID()
    var isAuthenticated: Bool
    var currentUser: UserInfo?
    var token: String? {
        didSet { sessionID = UUID() }
    }
    
    /// Inicializa el mock con un estado específico
    /// - Parameters:
    ///   - isAuthenticated: Si el usuario está autenticado
    ///   - user: Usuario mock (opcional)
    ///   - token: Token mock (opcional)
    init(
        isAuthenticated: Bool = false,
        user: UserInfo? = nil,
        token: String? = nil
    ) {
        self.isAuthenticated = isAuthenticated
        self.currentUser = user
        self.token = token
    }
    
    func saveAuth(token: String, user: UserInfo) {
        self.token = token
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func updateUser(_ user: UserInfo) {
        self.currentUser = user
    }
    
    func signOut() {
        token = nil
        currentUser = nil
        isAuthenticated = false
    }
}
#endif


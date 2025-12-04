//
//  AuthManaging.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation

/// Protocolo para gestionar autenticación, permite mocking en tests y previews
@MainActor
protocol AuthManaging {
    /// Indica si el usuario está autenticado
    var isAuthenticated: Bool { get }
    
    /// Información del usuario actual
    var currentUser: UserInfo? { get }
    
    /// Token JWT actual
    var token: String? { get set }
    
    /// Guarda la autenticación después de un login exitoso
    /// - Parameters:
    ///   - token: El token JWT recibido del backend
    ///   - user: La información del usuario
    func saveAuth(token: String, user: UserInfo)
    
    /// Cierra sesión y limpia todos los datos de autenticación
    func signOut()
}


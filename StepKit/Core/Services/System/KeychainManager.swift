//
//  KeychainManager.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import Foundation
import Security

protocol KeychainStoring: AnyObject {
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func get<T: Codable>(forKey key: String) throws -> T?
    func saveString(_ value: String, forKey key: String) throws
    func getString(forKey key: String) throws -> String?
    func delete(forKey key: String) throws
}

/// Utilidad para guardar y recuperar datos del Keychain de forma segura
final class KeychainManager: KeychainStoring {
    static let shared = KeychainManager()
    
    private let service: String
    
    private init() {
        // Usar el bundle ID como servicio para identificar los items del Keychain
        self.service = Bundle.main.bundleIdentifier ?? "app.stepkit.StepKit"
    }
    
    // MARK: - Generic Save/Get Methods
    
    /// Guarda un valor en el Keychain
    /// - Parameters:
    ///   - value: El valor a guardar (debe ser Codable)
    ///   - key: La clave para identificar el valor
    /// - Throws: Error si no se puede guardar
    func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try saveData(data, forKey: key)
    }
    
    /// Recupera un valor del Keychain
    /// - Parameter key: La clave del valor a recuperar
    /// - Returns: El valor decodificado, o nil si no existe
    /// - Throws: Error si no se puede decodificar
    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = try getData(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Guarda un String en el Keychain (método de conveniencia)
    func saveString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try saveData(data, forKey: key)
    }
    
    /// Recupera un String del Keychain (método de conveniencia)
    func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Elimina un valor del Keychain
    /// - Parameter key: La clave del valor a eliminar
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveData(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Primero intentar actualizar si existe
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecItemNotFound {
            // Si no existe, crear nuevo
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledError(status: updateStatus)
        }
    }
    
    private func getData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        
        return result as? Data
    }
}

// MARK: - Keychain Errors

enum KeychainError: Error, LocalizedError {
    case encodingError
    case unhandledError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Error al codificar el valor"
        case .unhandledError(let status):
            return "Error del Keychain: \(status)"
        }
    }
}


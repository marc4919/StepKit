//
//  AIConsentManager.swift
//  StepKit
//
//  Created by Assistant on 2025-12-13.
//

import Foundation

/// Gestor del consentimiento para uso de IA externa
/// Cumple con las normas de Apple de noviembre 2025 (Guideline 5.1.2(i))
@MainActor
@Observable
final class AIConsentManager {
    
    // MARK: - AppStorage Keys
    
    private let consentKey = "hasGivenAIConsent"
    private let consentDateKey = "aiConsentDate"
    
    // MARK: - State
    
    /// Indica si el usuario ha dado su consentimiento explícito para el uso de IA externa
    var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }
    
    /// Fecha en que se dio el consentimiento
    var consentDate: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: consentDateKey) as? Date else {
            return nil
        }
        return timestamp
    }
    
    // MARK: - Actions
    
    /// Guarda el consentimiento del usuario
    /// - Parameter date: Fecha del consentimiento (por defecto: ahora)
    func giveConsent(date: Date = Date()) {
        UserDefaults.standard.set(true, forKey: consentKey)
        UserDefaults.standard.set(date, forKey: consentDateKey)
    }
    
    /// Revoca el consentimiento del usuario
    func revokeConsent() {
        UserDefaults.standard.removeObject(forKey: consentKey)
        UserDefaults.standard.removeObject(forKey: consentDateKey)
    }
    
    /// Verifica si el usuario tiene consentimiento dado
    /// - Returns: `true` si tiene consentimiento, `false` en caso contrario
    func checkConsent() -> Bool {
        hasConsent
    }
}

//
//  KitStreamingState.swift
//  StepKit
//
//  Estado observable para gestionar el streaming de creación de kits
//

import Foundation
import Observation

/// Estado del streaming de creación de kits
@Observable
@MainActor
final class KitStreamingState {
    // MARK: - Estado del Kit
    
    /// Título del kit (llega con kit_info)
    var kitTitle: String?
    
    /// KPI del kit
    var kpi: String?
    
    /// Días de horizonte
    var horizonDays: Int?
    
    /// Riesgos identificados
    var risks: [String] = []
    
    // MARK: - Estado de Steps
    
    /// Steps que se van añadiendo
    var steps: [StreamStepOutput] = []
    
    /// Número total de steps esperados
    var totalSteps: Int?
    
    // MARK: - Estado de Completado
    
    /// Si el streaming ha terminado
    var isComplete = false
    
    /// ID del kit creado (llega con done)
    var kitId: UUID?
    
    /// Kit completo (llega con done)
    var kit: KitDTO?
    
    /// Uso de tokens
    var usage: UsageDTO?
    
    // MARK: - Estado de Error
    
    /// Mensaje de error si falla
    var error: String?
    
    /// Si hay un error
    var hasError: Bool { error != nil }
    
    // MARK: - Propiedades Computadas
    
    /// Progreso actual (0.0 a 1.0)
    var progress: Double {
        guard let total = totalSteps, total > 0 else { return 0.0 }
        return Double(steps.count) / Double(total)
    }
    
    /// Texto de estado para mostrar al usuario
    var statusText: String {
        if hasError {
            return "Error al crear el kit"
        }
        if isComplete {
            return "¡Kit creado!"
        }
        if let total = totalSteps {
            return "Generando paso \(steps.count + 1) de \(total)..."
        }
        if kitTitle != nil {
            return "Preparando los pasos..."
        }
        return "Conectando con la IA..."
    }
    
    // MARK: - Métodos para Actualizar Estado
    
    /// Procesa un evento del stream
    func handleEvent(_ event: AIChatStreamEvent) {
        switch event.eventType {
        case .kitInfo:
            kitTitle = event.kitTitle
            kpi = event.kpi
            horizonDays = event.horizonDays
            risks = event.risks ?? []
            
        case .step:
            if let step = event.step {
                steps.append(step)
            }
            if totalSteps == nil {
                totalSteps = event.totalSteps
            }
            
        case .done:
            isComplete = true
            kitId = event.kitId
            kit = event.kit
            usage = event.usage
            
        case .error:
            error = event.error ?? "Error desconocido"
            
        case .unknown:
            break
        }
    }
    
    /// Reinicia el estado para un nuevo intento
    func reset() {
        kitTitle = nil
        kpi = nil
        horizonDays = nil
        risks = []
        steps = []
        totalSteps = nil
        isComplete = false
        kitId = nil
        kit = nil
        usage = nil
        error = nil
    }
    
    /// Establece un error manualmente
    func setError(_ message: String) {
        error = message
    }
}



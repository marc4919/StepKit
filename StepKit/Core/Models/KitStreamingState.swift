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
    
    // MARK: - Modo del plan

    /// El servidor prepara este Kit con más cuidado (salud, dinero, plazos…).
    var isCareful = false

    /// Motivos del modo cuidado, tal como los envía el servidor ("health", "tight_deadline"…).
    var carefulReasons: [String] = []

    /// El servidor ha empezado de nuevo con otro modelo: lo recibido se sustituye.
    var isRestarting = false

    /// Preguntas del servidor antes de generar un Kit delicado; vacías cuando no hay.
    var pendingQuestions: [KitQuestion] = []

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
        if isRestarting {
            return "Ajustando tu plan…"
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
        case .planMode:
            isCareful = event.mode == "careful"
            carefulReasons = isCareful ? Array((event.reasons ?? []).prefix(3)) : []

        case .questions:
            pendingQuestions = Array((event.questions ?? []).prefix(3))

        case .restart:
            kitTitle = nil
            kpi = nil
            horizonDays = nil
            risks = []
            steps = []
            totalSteps = nil
            isRestarting = true

        case .kitInfo:
            isRestarting = false
            kitTitle = event.kitTitle
            kpi = event.kpi
            horizonDays = event.horizonDays
            risks = event.risks ?? []
            
        case .step:
            if let step = event.step {
                steps.append(step)
            }
            if let total = event.totalSteps {
                totalSteps = total
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
        pendingQuestions = []
        isCareful = false
        carefulReasons = []
        isRestarting = false
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



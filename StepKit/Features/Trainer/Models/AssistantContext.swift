//
//  AssistantContext.swift
//  StepKit
//
//  Estructuras para pasar contexto del usuario al Foundation Model
//

import Foundation

// MARK: - Assistant Context

/// Contexto completo del usuario para el asistente
struct AssistantContext {
    let kits: [KitSummary]
    let totalProgress: Double
    let upcomingDeadlines: [DeadlineInfo]
    let today: Date

    /// Genera una representación en texto del contexto para el modelo
    func toPromptString() -> String {
        var result = ""

        // Resumen global
        if kits.isEmpty {
            result += "El usuario no tiene kits creados todavía.\n"
        } else {
            result += "RESUMEN GLOBAL:\n"
            result += "- Total de kits: \(kits.count)\n"
            result += "- Progreso promedio: \(Int(totalProgress * 100))%\n"
            result += "- Kits activos: \(kits.filter { $0.progress < 1.0 }.count)\n"
            result += "- Kits completados: \(kits.filter { $0.progress >= 1.0 }.count)\n\n"

            // Detalle de cada kit
            result += "KITS DEL USUARIO:\n"
            for kit in kits {
                // Sin numerar: el modelo leía «1. Título del Kit» como si fuera el primer paso.
                result += "- Kit (objetivo): «\(kit.title)»\n"
                result += "   - Pasos completados: \(kit.completedSteps) de \(kit.totalSteps)\n"
                if let nextStep = kit.nextStep {
                    result += "   - Próximo paso: \"\(nextStep)\"\n"
                }
                if let deadline = kit.dueDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.locale = Locale(identifier: "es_ES")
                    result += "   - Fecha límite: \(formatter.string(from: deadline))\n"
                }
            }

            // Próximas fechas límite
            if !upcomingDeadlines.isEmpty {
                result += "\nPRÓXIMAS FECHAS LÍMITE:\n"
                for deadline in upcomingDeadlines.prefix(5) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.locale = Locale(identifier: "es_ES")
                    result += "- \(deadline.stepTitle) (\(deadline.kitTitle)): \(formatter.string(from: deadline.deadline))\n"
                }
            }
        }

        return result
    }
}

// MARK: - Kit Summary

/// Resumen de un kit para el contexto del asistente
struct KitSummary {
    let id: UUID
    let title: String
    let kpi: String
    let progress: Double
    let completedSteps: Int
    let totalSteps: Int
    let nextStep: String?
    let nextStepEstimateMinutes: Int?
    let dueDate: Date?
    let risks: [String]
}

// MARK: - Deadline Info

/// Información sobre una fecha límite próxima
struct DeadlineInfo {
    let stepTitle: String
    let kitTitle: String
    let deadline: Date
    let daysRemaining: Int
}

// MARK: - Quick Action Type

/// Tipos de acciones rápidas del asistente
enum QuickActionType: String {
    case motivation = "motivation"
    case tips = "tips"
    case faq = "faq"
    case progress = "progress"

    /// Contexto adicional para incluir en el prompt según el tipo de acción
    func additionalPromptContext(for context: AssistantContext) -> String {
        switch self {
        case .motivation:
            return """
            El usuario pide MOTIVACIÓN. Debes:
            - Ser inspirador y positivo
            - Celebrar su progreso actual (\(Int(context.totalProgress * 100))%)
            - Animar a seguir adelante con sus objetivos
            - Si tiene kits completados, felicitarlo
            - Si tiene poco progreso, motivarlo sin juzgar
            """

        case .tips:
            let nextSteps = context.kits.compactMap { kit -> String? in
                guard let step = kit.nextStep else { return nil }
                let timeStr = kit.nextStepEstimateMinutes.map { " (~\($0) min)" } ?? ""
                return "- \"\(step)\"\(timeStr) del kit \"\(kit.title)\""
            }
            return """
            El usuario pide CONSEJOS. Debes:
            - Dar tips prácticos y accionables
            - Basarte en sus próximos pasos pendientes:
            \(nextSteps.joined(separator: "\n"))
            - Sugerir cómo abordar el siguiente paso
            - Ser específico, no genérico
            """

        case .faq:
            return """
            El usuario tiene PREGUNTAS sobre la app. StepKit funciona así:
            - Los "Kits" son planes de acción para objetivos
            - Cada Kit tiene "Pasos" con fechas sugeridas
            - Se pueden marcar pasos como completados
            - El progreso se calcula automáticamente
            - El asistente (tú) ayuda con motivación y consejos
            Responde preguntas sobre estas funcionalidades.
            """

        case .progress:
            return """
            El usuario quiere ver su PROGRESO. Debes:
            - Dar un resumen claro de su estado actual
            - Mencionar kits activos y completados
            - Destacar logros recientes
            - Si hay fechas próximas, mencionarlas
            - Ser específico con números y porcentajes
            """
        }
    }
}

// MARK: - Assistant Context Builder

extension AssistantContext {
    /// Crea un contexto vacío (para cuando no hay kits)
    static var empty: AssistantContext {
        AssistantContext(
            kits: [],
            totalProgress: 0,
            upcomingDeadlines: [],
            today: Date()
        )
    }
}


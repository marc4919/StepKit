//
//  MockDataGenerators.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import Foundation

enum MockDataGenerators {
    static func createMockStreamSteps(goalDescription: String, dueDate: String) -> [StreamStepOutput] {
        return [
            StreamStepOutput(
                stepTitle: "Investigar y planificar",
                description: StreamDescriptionOutput(
                    short: "Investiga sobre '\(goalDescription.prefix(30))' y crea un plan inicial",
                    long: "Dedica tiempo a investigar los fundamentos y mejores prácticas relacionadas con tu objetivo."
                ),
                estimateMinutes: 45,
                suggestedDeadline: dueDate,
                effortLevel: "medium",
                adaptsTo: "Puedes dividirlo en sesiones más cortas",
                blockedByPremium: false
            ),
            StreamStepOutput(
                stepTitle: "Primeros pasos prácticos",
                description: StreamDescriptionOutput(
                    short: "Empieza con las acciones básicas",
                    long: "Comienza a practicar o ejecutar las primeras acciones hacia tu objetivo."
                ),
                estimateMinutes: 60,
                suggestedDeadline: dueDate,
                effortLevel: "medium",
                adaptsTo: "Ajusta la intensidad según tu disponibilidad",
                blockedByPremium: false
            ),
            StreamStepOutput(
                stepTitle: "Consolidar el progreso",
                description: StreamDescriptionOutput(
                    short: "Refuerza lo aprendido y avanza",
                    long: "Revisa tu progreso, identifica áreas de mejora y continúa avanzando."
                ),
                estimateMinutes: 45,
                suggestedDeadline: dueDate,
                effortLevel: "medium",
                adaptsTo: "Puedes hacer revisiones más frecuentes si lo prefieres",
                blockedByPremium: false
            ),
            StreamStepOutput(
                stepTitle: "Completar el objetivo",
                description: StreamDescriptionOutput(
                    short: "Finaliza y evalúa tu progreso",
                    long: "Realiza las acciones finales para completar tu objetivo."
                ),
                estimateMinutes: 30,
                suggestedDeadline: dueDate,
                effortLevel: "low",
                adaptsTo: "Dedica el tiempo necesario para una buena evaluación final",
                blockedByPremium: false
            )
        ]
    }
    
    static func createMockKitDTO(kitId: UUID, goalDescription: String, dueDate: String, risks: [String]) -> KitDTO {
        let now = Date()
        let steps = createMockSteps(for: kitId, goalDescription: goalDescription, dueDate: dueDate)
        
        return KitDTO(
            id: kitId,
            userId: nil,
            title: "Plan: \(goalDescription.prefix(50))",
            kpi: "Completar todos los pasos del plan",
            horizonDays: Calendar.current.dateComponents([.day], from: now, to: dateFromString(dueDate) ?? now).day ?? 30,
            metaType: "personal",
            metaTags: ["generated", "ai"],
            risks: risks,
            version: 1,
            progress: 0.0,
            sourceModel: "mock-model",
            promptVersion: 1,
            rawArguments: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            deleted: false,
            steps: steps
        )
    }
    
    static func createMockKitResponse(from request: AIGenerateKitRequest) -> AIGenerateKitResponse {
        let kitId = UUID()
        let now = Date()
        
        // Crear pasos mock basados en la descripción
        let steps = createMockSteps(for: kitId, goalDescription: request.goalDescription, dueDate: request.dueDate)
        
        let kit = KitDTO(
            id: kitId,
            userId: nil,
            title: "Plan: \(request.goalDescription.prefix(50))",
            kpi: "Completar todos los pasos del plan",
            horizonDays: Calendar.current.dateComponents([.day], from: now, to: dateFromString(request.dueDate) ?? now).day ?? 30,
            metaType: "personal",
            metaTags: ["generated", "ai"],
            risks: request.inconveniences,
            version: 1,
            progress: 0.0,
            sourceModel: "mock-model",
            promptVersion: 1,
            rawArguments: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            deleted: false,
            steps: steps
        )
        
        return AIGenerateKitResponse(
            kit: kit,
            rawResponse: "Mock response",
            usage: UsageDTO(tokensIn: 150, tokensOut: 500, model: "mock-model")
        )
    }
    
    static func createMockSteps(for kitId: UUID, goalDescription: String, dueDate: String) -> [StepDTO] {
        let now = Date()
        let targetDate = dateFromString(dueDate) ?? Calendar.current.date(byAdding: .day, value: 30, to: now)!
        let totalDays = Calendar.current.dateComponents([.day], from: now, to: targetDate).day ?? 30
        
        return [
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Investigar y planificar",
                descriptionShort: "Investiga sobre '\(goalDescription.prefix(30))' y crea un plan inicial",
                descriptionLong: "Dedica tiempo a investigar los fundamentos y mejores prácticas relacionadas con tu objetivo. Crea un plan detallado con hitos intermedios.",
                estimateMinutes: 45,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(1, totalDays / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Puedes dividirlo en sesiones más cortas",
                blockedByPremium: false,
                order: 0,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Primeros pasos prácticos",
                descriptionShort: "Empieza con las acciones básicas",
                descriptionLong: "Comienza a practicar o ejecutar las primeras acciones hacia tu objetivo. No te preocupes por la perfección, enfócate en el progreso.",
                estimateMinutes: 60,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(2, totalDays * 2 / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Ajusta la intensidad según tu disponibilidad",
                blockedByPremium: false,
                order: 1,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Consolidar el progreso",
                descriptionShort: "Refuerza lo aprendido y avanza",
                descriptionLong: "Revisa tu progreso, identifica áreas de mejora y continúa avanzando. Este es el momento de ajustar tu enfoque si es necesario.",
                estimateMinutes: 45,
                suggestedDeadline: Calendar.current.date(byAdding: .day, value: max(3, totalDays * 3 / 5), to: now),
                effortLevel: "medium",
                adaptsTo: "Puedes hacer revisiones más frecuentes si lo prefieres",
                blockedByPremium: false,
                order: 2,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            StepDTO(
                id: UUID(),
                kitId: kitId,
                title: "Completar el objetivo",
                descriptionShort: "Finaliza y evalúa tu progreso",
                descriptionLong: "Realiza las acciones finales para completar tu objetivo. Evalúa lo que has aprendido y celebra tu logro.",
                estimateMinutes: 30,
                suggestedDeadline: targetDate,
                effortLevel: "low",
                adaptsTo: "Dedica el tiempo necesario para una buena evaluación final",
                blockedByPremium: false,
                order: 3,
                completed: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
        ]
    }
    
    static func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

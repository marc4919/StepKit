//
//  AssistantContextBuilder.swift
//  StepKit
//
//  Construye el contexto del asistente a partir de los Goals.
//

import Foundation

enum AssistantContextBuilder {

    /// Construye el contexto completo para el asistente
    static func build(from goals: [GoalEntity]) -> AssistantContext {
        let kitSummaries = goals.map { entity -> KitSummary in
            let completedSteps = entity.steps.filter { $0.isCompleted }.count
            let sortedPendingSteps = entity.steps
                .filter { !$0.isCompleted }
                .sorted { $0.order < $1.order }

            let nextStep = sortedPendingSteps.first
            let dueDate = entity.steps
                .compactMap { $0.suggestedDeadline }
                .max()

            return KitSummary(
                id: entity.id,
                title: entity.planTitle,
                kpi: entity.kpi,
                progress: entity.computedProgress,
                completedSteps: completedSteps,
                totalSteps: entity.steps.count,
                nextStep: nextStep?.stepTitle,
                nextStepEstimateMinutes: nextStep?.estimateMinutes,
                dueDate: dueDate,
                risks: entity.risks
            )
        }

        let totalProgress = goals.isEmpty ? 0 :
            goals.map { $0.computedProgress }.reduce(0, +) / Double(goals.count)

        let upcomingDeadlines = buildUpcomingDeadlines(from: goals)

        return AssistantContext(
            kits: kitSummaries,
            totalProgress: totalProgress,
            upcomingDeadlines: upcomingDeadlines,
            today: Date()
        )
    }

    /// Construye la lista de deadlines próximos (2 semanas)
    static func buildUpcomingDeadlines(from goals: [GoalEntity]) -> [DeadlineInfo] {
        var deadlines: [DeadlineInfo] = []
        let calendar = Calendar.current
        let today = Date()

        for entity in goals {
            for step in entity.steps where !step.isCompleted {
                if let deadline = step.suggestedDeadline {
                    let days = calendar.dateComponents([.day], from: today, to: deadline).day ?? 0
                    if days >= 0 && days <= 14 {
                        deadlines.append(DeadlineInfo(
                            stepTitle: step.stepTitle,
                            kitTitle: entity.planTitle,
                            deadline: deadline,
                            daysRemaining: days
                        ))
                    }
                }
            }
        }

        return deadlines.sorted { $0.deadline < $1.deadline }
    }

    /// Verifica si todos los kits están completados
    static func areAllKitsCompleted(goals: [GoalEntity]) -> Bool {
        guard !goals.isEmpty else { return false }
        return goals.allSatisfy { entity in
            entity.steps.allSatisfy { $0.isCompleted }
        }
    }
}

//
//  Playground.swift
//  StepKit Playground
//
//  Created by Marc Garcia Teodoro on 24/10/25.
//

import Playgrounds
import FoundationModels
import Foundation

// MARK: - Original Simple Test (Commented)
/*
#Playground {
    let session = LanguageModelSession(instructions: kitInstructions)

    let today = todayISO(in: "Europe/Madrid")
    let prompt = """
    goal_description: Quiero perder dos kilos, \
    dueDate: 2025-12-28, \
    today: \(today), \
    timezone: Europe/Madrid, \
    dailyAvailableTime: 60, \
    maxStepsPerDay: 2, \
    inconveniences: No tengo gimnasio cerca, me falta un brazo
    """

    let response = try await session.respond(to: prompt, generating: Kit.self).content
    print(response)
}
*/

// MARK: - Router + Model Selection Test
#Playground {
    let today = todayISO(in: "Europe/Madrid")

    let goalDescription = "Quiero hacer una maraton"
    let dueDate = "2025-12-28"
    let inconveniences = "No suelo correr"

    let routerSession = LanguageModelSession(instructions: routerInstructions)
    let routerPrompt = """
    goal_description: \(goalDescription), \
    dueDate: \(dueDate), \
    today: \(today), \
    inconveniences: \(inconveniences)
    """

    let recommendation = try await routerSession.respond(to: routerPrompt, generating: ModelRecommendation.self).content

    print("🚀 STEP 2: Generating roadmap with \(recommendation.recommendedModel) model...\n")

    if recommendation.recommendedModel == "lightweight" {
        print("✅ Using lightweight API model\n")
    } else {
        print("⚠️  Using heavyweight API model")
    }
}

// MARK: - Tutorial Example: Learning Kit

let learningKitInstructions = """
You are a learning plan generator. Create a structured plan to help users learn new skills.
Provide a clear roadmap with actionable milestones.
"""

@Generable(
    description: "Simple learning plan with key milestones to achieve the goal."
)
struct LearningPlan {
    @Guide(description: "Name of the skill or topic to learn.")
    var skillName: String

    @Guide(
        description: "Total duration of the learning plan in weeks.",
        .minimum(1), .maximum(52)
    )
    var totalWeeks: Int

    @Guide(
        description: "Key milestones or steps to complete the learning journey."
    )
    var milestones: [String]
}

#Playground {
    let session = LanguageModelSession(instructions: learningKitInstructions)

    let prompt = """
    Create a 4-week plan to learn basic guitar playing.
    User has 30 minutes per day available.
    """

    let plan = try await session.respond(to: prompt, generating: LearningPlan.self).content
    print("🎸 Learning Plan: \(plan.skillName)")
    print("Duration: \(plan.totalWeeks) weeks\n")
    print("Milestones:")
    for (index, milestone) in plan.milestones.enumerated() {
        print("  \(index + 1). \(milestone)")
    }
}

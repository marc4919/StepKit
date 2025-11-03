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

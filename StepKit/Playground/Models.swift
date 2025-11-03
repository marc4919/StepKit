//
//  Models.swift
//  StepKit Playground
//
//  Created by Marc Garcia Teodoro on 24/10/25.
//

import Foundation
import FoundationModels

@Generable(
    description: "Step-by-step roadmap for a user's goal by the target date, adapting to available time and constraints."
)
struct Kit: Identifiable {
    let id = UUID()

    @Guide(description: "Short, action-oriented title of the plan (same language as `goal_description`).")
    var title: String

    @Guide(
        description: "Horizon in days from `today` to `dueDate` (integer). Compute as ceil(days(today→dueDate)).",
        .minimum(0), .maximum(365)
    )
    var horizonDays: Int

    @Guide(description: "A single measurable KPI for success at due date (tempo/time-bound, recording, or count).")
    var kpi: String

    @Guide(
        description: "Top risks with mitigation using ' → '.",
        .minimumCount(2)
    )
    var risks: [String]?

    @Guide(
        description: "Ordered list of atomic steps (25–90 minutes each). EVERY step must be concrete and adapted to inconveniences. If longer or > dailyAvailableTime, split. Spread steps across days (≤ maxStepsPerDay).",
        .minimumCount(3)
    )
    var steps: [PlanStep]
}

@Generable(
    description: "Dual description for a step: short (preview) and long (detailed guidance)."
)
struct StepDescription {
    @Guide(description: "Short preview (≈1 line) with concrete action and numbers.")
    var short: String

    @Guide(description: "Long, detailed guidance with exact method, quantities, adaptation to inconveniences, and success criteria (2–3 sentences).")
    var long: String
}

@Generable(
    description: "Atomic, actionable step that can be completed in a single focused session (25–90 minutes). Must be specific and adapted to user's inconveniences."
)
struct PlanStep: Identifiable {
    let id = UUID()

    @Guide(description: "Short, imperative step title with concrete verb + what (no vague verbs like 'buscar', 'establecer').")
    var stepTitle: String

    @Guide(description: "Short/long descriptions for preview and detail. Must include numbers, specific methods, and adaptation to constraints.")
    var description: StepDescription

    @Guide(
        description: "Estimated effort in minutes. Must be 25–90; if it needs more, split into parts.",
        .minimum(25), .maximum(90)
    )
    var estimateMinutes: Int

    @Guide(
        description: "Suggested deadline (YYYY-MM-DD), never after dueDate. Avoid > maxStepsPerDay."
    )
    var suggestedDeadline: String
}

@Generable(
    description: "Recommendation for which AI model to use based on goal complexity analysis."
)
struct ModelRecommendation {
    @Guide(description: "Recommended model", .anyOf(["lightweight", "heavyweight"]))
    var recommendedModel: String

    @Guide(
        description: "Confidence level in the recommendation (0-100).",
        .range(0...100)
    )
    var confidence: Int

    @Guide(description: "1-2 sentence explanation in same language as goal_description.")
    var reasoning: String
}

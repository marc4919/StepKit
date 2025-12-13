//
//  Playground.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro
//

import Playgrounds
import FoundationModels

let kitInstruction = """
    You are a learning plan generator. Create a structured plan to help users learn new skills.
    Provide a clear roadmap with actionable milestones.
"""

@Generable(
    description: "Simple learning plan with key milestones to achieve the goal."
)
struct Plan {
    @Guide(description: "Name of the skill or topic to learn.")
    var skillName: String
    
    @Guide(description: "Total number of weeks to complete the learning plan.", .minimum(1), .maximum(52))
    var totalWeeks: Int
    
    @Guide(description: "Key milestones or steps to complete")
    var milestones: [String]
}

#Playground {
    let session = LanguageModelSession(instructions: kitInstructions)
    
    let prompt = "Create a 4-week plan to learn basic guitar playing"
    
    _ = try await session.respond(to: prompt, generating: Plan.self).content
}

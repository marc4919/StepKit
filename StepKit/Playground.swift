//
//  Playground.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 24/10/25.
//

import Playgrounds
import FoundationModels

@Generable()
struct Recipe {
    @Guide(description: "The name of the recipe.")
    let name: String
    @Guide(description: "The description of the recipe.")
    let description: String
}

#Playground {    
    let session = LanguageModelSession()
        let response = try await session.respond(to: "Suggest a tradional Pakistani recipe", generating: Recipe.self)
        
        print(response.content)
        print(response.content.name)
        print(response.content.description)
}

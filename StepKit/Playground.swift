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
    @Guide(description: "The Steps of the recipe.")
    let steps: [String]
}

var answer: Recipe.PartiallyGenerated?

#Playground {
    do{
        let session = LanguageModelSession()
        let stream = session.streamResponse(to: "Suggest a tradional Bravas", generating: Recipe.self)
        
        for try await partialResponse in stream {
            answer = partialResponse.content
        }
        
        let article = try await stream.collect()
        print(article.content.steps)
    } catch {
        print("Error generating recipe: \(error)")
    }
}

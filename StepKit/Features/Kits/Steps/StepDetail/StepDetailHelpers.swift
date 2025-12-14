//
//  StepDetailHelpers.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import Foundation
import SwiftUI

enum StepDetailHelpers {
    /// Formatea minutos en formato legible (ej: "45 min", "1h 30m", "2h")
    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    /// Devuelve el texto del nivel de esfuerzo en español
    static func effortLevelText(for effortLevel: String) -> String {
        switch effortLevel.lowercased() {
        case "low": return "Bajo"
        case "medium": return "Medio"
        case "high": return "Alto"
        default: return effortLevel.capitalized
        }
    }
    
    /// Devuelve el índice del nivel de esfuerzo (1-3)
    static func effortLevelIndex(for effortLevel: String) -> Int {
        switch effortLevel.lowercased() {
        case "low": return 1
        case "medium": return 2
        case "high": return 3
        default: return 1
        }
    }
    
    /// Devuelve el color según el nivel de esfuerzo
    static func effortColor(for effortLevel: String) -> Color {
        switch effortLevel.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .accentColor
        }
    }
    
    /// Devuelve el icono según el nivel de esfuerzo
    static func effortIcon(for effortLevel: String) -> String {
        switch effortLevel.lowercased() {
        case "low": return "leaf.fill"
        case "medium": return "flame.fill"
        case "high": return "bolt.fill"
        default: return "gauge"
        }
    }
    
    /// Divide el texto en párrafos basándose en oraciones largas (>80 chars que terminan en punto)
    static func formattedParagraphs(from text: String) -> [String] {
        let threshold = 80

        // Dividir por oraciones (punto seguido de espacio o fin)
        let sentences = text.components(separatedBy: ". ")

        var paragraphs: [String] = []
        var currentParagraph = ""

        for (index, sentence) in sentences.enumerated() {
            let sentenceWithPeriod = index < sentences.count - 1 ? sentence + "." : sentence

            if currentParagraph.isEmpty {
                currentParagraph = sentenceWithPeriod
            } else {
                currentParagraph += " " + sentenceWithPeriod
            }

            // Si el párrafo actual supera el umbral, guardarlo y empezar uno nuevo
            if currentParagraph.count >= threshold {
                paragraphs.append(currentParagraph)
                currentParagraph = ""
            }
        }

        // Añadir el último párrafo si queda algo
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }

        // Si no se dividió en párrafos, devolver el texto original
        return paragraphs.isEmpty ? [text] : paragraphs
    }
}

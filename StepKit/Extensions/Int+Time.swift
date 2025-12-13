//
//  Int+Time.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import Foundation

extension Int {
    /// Formatea un valor entero de minutos a una cadena legible (e.g., "1h 30m" o "45 min")
    func formattedDuration() -> String {
        let minutes = self
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
}

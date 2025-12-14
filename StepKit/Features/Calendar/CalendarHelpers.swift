//
//  CalendarHelpers.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import Foundation

enum CalendarHelpers {
    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
        }
    }
}

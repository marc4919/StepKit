//
//  CalendarNavigation.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import TipKit

// MARK: - Tip
struct CreateKitFromCalendarTip: Tip {
    var title: Text {
        Text("Crear kit")
    }

    var message: Text? {
        Text("Pulsa para crear un nuevo kit con la fecha seleccionada")
    }
}

// MARK: - Navigation Wrappers
struct GoalNavigation: Hashable {
    let id: UUID
}

struct StepNavigation: Hashable {
    let id: UUID
}

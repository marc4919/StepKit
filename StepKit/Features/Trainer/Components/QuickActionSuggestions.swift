//
//  QuickActionSuggestions.swift
//  StepKit
//
//  Extracted from TrainerView.swift
//

import SwiftUI

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}


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

// MARK: - Quick Actions View

struct QuickActionSuggestions: View {
    let actions: [QuickAction]
    let onActionTapped: (QuickAction) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(actions) { action in
                    Button {
                        onActionTapped(action)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.subheadline)
                            Text(action.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground).opacity(0.5))
    }
}

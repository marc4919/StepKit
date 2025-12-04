//
//  StepRowView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Celda de un paso en la lista de pasos de un kit
struct StepRowView: View {
    let step: Step
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(step.isCompleted ? .green : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(step.description.short)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isCompleted ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview("Completado") {
    StepRowView(step: .preview)
        .padding()
}

#Preview("Pendiente") {
    StepRowView(step: .previewPending)
        .padding()
}


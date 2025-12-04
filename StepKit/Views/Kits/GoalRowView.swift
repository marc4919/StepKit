//
//  GoalRowView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Celda de un objetivo/kit en la lista
struct GoalRowView: View {
    let goal: Goal
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 14) {
            // Indicador de progreso circular
            progressIndicator
            
            // Contenido principal
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(goal.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Fecha objetivo
                if let dueDate = goal.dueDate, !goal.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                    }
                    .foregroundColor(isDueSoon ? .orange : .secondary)
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    goal.isCompleted
                        ? Color.green.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        ZStack {
            // Fondo del círculo
            Circle()
                .stroke(accentBlue.opacity(0.15), lineWidth: 4)
                .frame(width: 48, height: 48)
            
            // Progreso
            Circle()
                .trim(from: 0, to: goal.progress)
                .stroke(
                    goal.isCompleted
                        ? LinearGradient(colors: [.green, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
            
            // Contenido central
            if goal.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
            } else {
                Text("\(Int(goal.progress * 100))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(accentBlue)
            }
        }
    }
    
    // MARK: - Helpers
    private var isDueSoon: Bool {
        guard let dueDate = goal.dueDate else { return false }
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysRemaining <= 3 && daysRemaining >= 0
    }
}

#Preview("En progreso") {
    GoalRowView(goal: .preview)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Completado") {
    GoalRowView(goal: .previewCompleted)
        .padding()
        .background(Color(.systemGroupedBackground))
}

//
//  GoalDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header con título y estado
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(goal.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Progreso visual
                VStack(alignment: .leading, spacing: 12) {
                    Text("Progreso")
                        .font(.headline)
                    
                    if goal.isCompleted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                            Text("¡Objetivo Completado!")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(Int(goal.progress * 100))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("completado")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: goal.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(y: 2)
                        }
                    }
                }
                
                // Fecha de vencimiento
                if let dueDate = goal.dueDate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha límite")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                            Text(dueDate, style: .date)
                                .font(.body)
                        }
                    }
                }
                
                // Estadísticas o acciones adicionales
                VStack(alignment: .leading, spacing: 12) {
                    Text("Acciones")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Editar objetivo")
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        
                        if !goal.isCompleted {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Actualizar progreso")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Detalles")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    GoalDetailView(
        goal: Goal(
            title: "Ejemplo",
            description: "Descripción de ejemplo",
            progress: 0.75,
            isCompleted: false,
            dueDate: Date()
        )
    )
}

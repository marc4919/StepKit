//
//  ExperimentCardView.swift
//  StepKitPlayground
//
//  Created by Marc Garcia Teodoro on 14/12/25.
//

import SwiftUI

struct ExperimentCardView: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icono del experimento
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            
            // Información del experimento
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Indicador de navegación
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 12) {
        ExperimentCardView(
            title: "Router + Model Selection Test",
            description: "Prueba el sistema de routing que selecciona el modelo apropiado según la complejidad del objetivo",
            icon: "brain.head.profile"
        )
        
        ExperimentCardView(
            title: "Learning Kit Example",
            description: "Ejemplo de generación de plan de aprendizaje con milestones estructurados",
            icon: "book.fill"
        )
    }
    .padding()
}


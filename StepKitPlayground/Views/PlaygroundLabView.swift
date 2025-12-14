//
//  PlaygroundLabView.swift
//  StepKitPlayground
//
//  Created by Marc Garcia Teodoro on 14/12/25.
//

import SwiftUI

struct PlaygroundLabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header del laboratorio
                    labHeader
                    
                    // Descripción del propósito
                    labDescription
                    
                    // Lista de experimentos
                    experimentsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("StepKit Lab")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header
    
    private var labHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "flask.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Laboratorio de Pruebas")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    // Badge de LAB
                    Text("LAB")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                
                Text("Entorno de experimentación y desarrollo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Descripción
    
    private var labDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                
                Text("Propósito")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Text("Este laboratorio permite probar y experimentar con modelos de lenguaje, generación de kits, y funcionalidades de StepKit sin afectar el código de producción.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
    
    // MARK: - Experimentos
    
    private var experimentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "testtube.2")
                    .foregroundStyle(.orange)
                
                Text("Experimentos Disponibles")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 12) {
                ExperimentCardView(
                    title: "Router + Model Selection Test",
                    description: "Prueba el sistema de routing que selecciona el modelo apropiado (lightweight o heavyweight) según la complejidad del objetivo",
                    icon: "brain.head.profile"
                )
                
                ExperimentCardView(
                    title: "Learning Kit Example",
                    description: "Ejemplo de generación de plan de aprendizaje con milestones estructurados usando FoundationModels",
                    icon: "book.fill"
                )
            }
        }
    }
}

#Preview {
    PlaygroundLabView()
}

//
//  EmptyStateContainerView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Contenedor principal del estado vacío con animación y mensaje
struct EmptyStateContainerView: View {
    @Binding var animateEmptyState: Bool
    @Binding var showingFastCreator: Bool
    
    // Colores compartidos
    private let sphereHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let sphereBase = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            // En landscape: caja más grande y fija
            let animationSize: CGFloat = isLandscape ? 160 : 240
            let spacing: CGFloat = isLandscape ? 12 : 28
            
            VStack(spacing: spacing) {
                if isLandscape {
                    // Espacio fijo en landscape para bajar el contenido
                    Spacer()
                        .frame(height: 50)
                } else {
                    // En portrait, Spacer flexible para centrar
                    Spacer()
                }
                
                // Animación principal del estado vacío
                TargetOrbitalHexView(animate: animateEmptyState, size: animationSize)
                    .frame(maxWidth: .infinity)
                
                // Mensaje + CTA
                EmptyStateMessageView(
                    title: "Da el primer paso",
                    subtitle: "Crea tu primer kit y empieza a avanzar",
                    buttonTitle: "Crear kit",
                    glowColor: glowColor,
                    sphereHighlight: sphereHighlight,
                    sphereBase: sphereBase
                ) {
                    showingFastCreator = true
                }
                
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            showingFastCreator = true
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateEmptyState = true
            }
        }
    }
}

#Preview {
    EmptyStateContainerView(
        animateEmptyState: .constant(true),
        showingFastCreator: .constant(false)
    )
}


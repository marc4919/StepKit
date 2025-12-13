//
//  EmptyStateMessageView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

/// Vista con el copy y botón CTA del estado vacío
struct EmptyStateMessageView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let glowColor: Color
    let sphereHighlight: Color
    let sphereBase: Color
    let action: () -> Void

    @State private var showButton = false

    var body: some View {
        VStack(spacing: 22) {
            // Textos agrupados
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Botón CTA
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(buttonTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [sphereHighlight, sphereBase],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showButton = true
            }
        }
        .onDisappear {
            showButton = false
        }
    }
}


#Preview {
    EmptyStateMessageView(
        title: "Da el primer paso",
        subtitle: "Crea tu primer kit y empieza a avanzar",
        buttonTitle: "Crear kit",
        glowColor: Color(red: 0.2, green: 0.6, blue: 1.0),
        sphereHighlight: Color(red: 0.55, green: 0.82, blue: 1.0),
        sphereBase: Color(red: 0.0, green: 0.48, blue: 1.0)
    ) {
        print("Crear kit tapped")
    }
}


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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle)")

            // Botón CTA
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityHidden(true)
                    Text(buttonTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(LinearGradient.accentGradient)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .glowShadow()
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("emptyState.primaryAction")
            .accessibilityLabel(buttonTitle)
            .accessibilityHint(String(localized: "Toca dos veces para \(buttonTitle.lowercased())"))
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
        title: String(localized: "Da el primer paso"),
        subtitle: String(localized: "Crea tu primer kit y empieza a avanzar"),
        buttonTitle: String(localized: "Crear kit")
    ) {
        print("Crear kit tapped")
    }
}

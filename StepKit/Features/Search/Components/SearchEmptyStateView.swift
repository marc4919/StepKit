//
//  SearchEmptyStateView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct SearchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icono con glow
            ZStack {
                // Glow de fondo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // Círculo con icono
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
            }

            // Texto
            VStack(spacing: 8) {
                Text("Encuentra tus kits y pasos")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Escribe en el buscador para empezar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

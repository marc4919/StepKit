//
//  KitInfoHeroHeader.swift
//  StepKit
//
//  Extracted from ExtendedKitInfoView.swift
//

import SwiftUI

struct KitInfoHeroHeader: View {
    let title: String
    let kpi: String
    let isCompleted: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Icono con glow
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isCompleted ? Color.green.opacity(0.3) : Color.accentHighlight.opacity(0.3),
                                isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)

                // Círculo de fondo
                Circle()
                    .fill(
                        isCompleted
                            ? LinearGradient.completedWithOpacity( 0.2)
                            : LinearGradient.accentWithOpacity( 0.2)
                    )
                    .frame(width: 64, height: 64)

                // Icono
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "info.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        isCompleted
                            ? LinearGradient.completedGradient
                            : LinearGradient.accentGradient
                    )
            }

            // Título
            VStack(spacing: 6) {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(kpi)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

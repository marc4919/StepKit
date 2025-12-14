//
//  KitHeaderView.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI

struct ExtendedKitInfoHeaderView: View {
    let goalEntity: GoalEntity
    
    var body: some View {
        VStack(spacing: 16) {
            // Icono con glow
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goalEntity.isCompleted ? Color.green.opacity(0.3) : Color.accentHighlight.opacity(0.3),
                                goalEntity.isCompleted ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1),
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
                        goalEntity.isCompleted
                            ? LinearGradient.completedWithOpacity( 0.2)
                            : LinearGradient.accentWithOpacity( 0.2)
                    )
                    .frame(width: 64, height: 64)

                // Icono
                Image(systemName: goalEntity.isCompleted ? "checkmark.seal.fill" : "info.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        goalEntity.isCompleted
                            ? LinearGradient.completedGradient
                            : LinearGradient.accentGradient
                    )
            }

            // Título
            VStack(spacing: 6) {
                Text(goalEntity.planTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(goalEntity.kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

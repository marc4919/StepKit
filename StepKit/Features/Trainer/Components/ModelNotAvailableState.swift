//
//  ModelNotAvailableState.swift
//  StepKit
//
//  Extracted from TrainerView.swift
//

import SwiftUI

struct ModelNotAvailableState: View {
    let title: String
    let message: String
    let showSettingsHint: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icono
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if showSettingsHint {
                    Text("Ajustes → Apple Intelligence y Siri")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
    }
}

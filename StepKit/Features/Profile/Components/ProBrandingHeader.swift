//
//  ProBrandingHeader.swift
//  StepKit
//
//  Extracted from SubscriptionView.swift
//

import SwiftUI

struct ProBrandingHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            // Icono premium con glow
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentHighlight.opacity(0.3), Color.accentColor.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)

                // Circulo de fondo
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.2))
                    .frame(width: 88, height: 88)

                // Corona
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.5), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: 6) {
                Text("StepKit Pro")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.primary)

                Text("Desbloquea todo el potencial")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
}

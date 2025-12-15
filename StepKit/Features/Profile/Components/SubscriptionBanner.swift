//
//  SubscriptionBanner.swift
//  StepKit
//
//  Banner de suscripción para el perfil.
//

import SwiftUI

struct SubscriptionBanner: View {
    var body: some View {
        NavigationLink(destination: SubscriptionView()) {
            HStack(spacing: 14) {
                // Icono
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Desbloquea StepKit Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("Accede a todas las funciones premium")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(LinearGradient.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glowShadow()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

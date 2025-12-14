//
//  ProfileHeaderSection.swift
//  StepKit
//
//  Header del perfil con avatar y nombre.
//

import SwiftUI

struct ProfileHeaderSection: View {
    let displayName: String
    let displayTier: String

    var body: some View {
        VStack(spacing: 12) {
            // Avatar del usuario
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity(0.3))
                    .frame(width: 80, height: 80)
                    .glowShadow(opacity: 0.3, radius: 12, y: 4)

                Image(systemName: "person.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
            }

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)

                Text(displayTier)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
}

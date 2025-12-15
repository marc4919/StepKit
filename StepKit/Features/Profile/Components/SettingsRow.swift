//
//  SettingsRow.swift
//  StepKit
//
//  Fila de configuración reutilizable.
//

import SwiftUI

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let showDivider: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(iconColor.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                    .accessibilityHidden(true)

                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                if showDivider {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityHint("Toca dos veces para abrir esta configuración")
    }
}

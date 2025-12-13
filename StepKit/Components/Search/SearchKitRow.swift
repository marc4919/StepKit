//
//  SearchKitRow.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct SearchKitRow: View {
    let kit: Goal
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icono circular
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                // Contenido
                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.planTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(kit.kpi)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .appCardStyle(backgroundColor: Color(.secondarySystemGroupedBackground))
        }
        .buttonStyle(.plain)
    }
}

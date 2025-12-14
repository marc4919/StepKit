//
//  KitRisksView.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI

struct KitRisksView: View {
    let risks: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "exclamationmark.shield.fill", title: "Riesgos Identificados")

            VStack(spacing: 10) {
                ForEach(Array(risks.enumerated()), id: \.offset) { index, risk in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 32, height: 32)

                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }

                        Text(risk)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.08), Color.orange.opacity(0.04)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 4)
    }
}

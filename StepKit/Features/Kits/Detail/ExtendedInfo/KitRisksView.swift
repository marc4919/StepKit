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
            sectionHeader(icon: "lightbulb.fill", title: String(localized: "A tener en cuenta"))

            VStack(spacing: 10) {
                ForEach(Array(risks.enumerated()), id: \.offset) { _, risk in
                    HStack(spacing: 12) {
                        let topic = RiskTopic(risk)
                        IconChip(symbol: topic.symbol, color: topic.tint, size: 32)

                        Text(risk)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.06), Color.accentColor.opacity(0.02)],
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

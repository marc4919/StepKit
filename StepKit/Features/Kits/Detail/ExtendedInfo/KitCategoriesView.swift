//
//  KitCategoriesView.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI

struct KitCategoriesView: View {
    let metaType: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: typeIcon(for: metaType))
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Tipo de objetivo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(localizedType(metaType))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func typeIcon(for type: String) -> String {
        switch type.lowercased() {
        case "health": return "heart.fill"
        case "learning": return "book.fill"
        case "fitness": return "figure.run"
        case "productivity": return "chart.bar.fill"
        case "finance": return "dollarsign.circle.fill"
        case "creative": return "paintbrush.fill"
        default: return "star.fill"
        }
    }

    private func localizedType(_ type: String) -> String {
        switch type.lowercased() {
        case "health": return "Salud"
        case "learning": return "Aprendizaje"
        case "fitness": return "Fitness"
        case "productivity": return "Productividad"
        case "finance": return "Finanzas"
        case "creative": return "Creatividad"
        case "setup": return "Configuración"
        default: return type.capitalized
        }
    }
}

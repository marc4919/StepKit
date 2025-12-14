//
//  StepMetadataCard.swift
//  StepKit
//
//  Extracted from StepDetailView.swift
//

import SwiftUI

struct StepMetadataCard: View {
    let estimateMinutes: Int
    let suggestedDeadline: Date?
    let effortLevel: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Tiempo estimado
            detailRow(
                icon: "clock.fill",
                iconColor: .accentColor,
                title: "Tiempo estimado",
                value: formatMinutes(estimateMinutes),
                showDivider: true
            )
            
            // Fecha sugerida
            if let deadline = suggestedDeadline {
                detailRow(
                    icon: "calendar",
                    iconColor: .purple,
                    title: "Fecha sugerida",
                    value: deadline.formatted(.dateTime.day().month(.wide)),
                    showDivider: true
                )
            }
            
            // Nivel de esfuerzo
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: effortIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(effortColor)
                        .frame(width: 24)
                    
                    Text("Nivel de esfuerzo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    effortIndicator
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Detail Row
    
    private func detailRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        showDivider: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }
    
    // MARK: - Effort Indicator
    
    private var effortIndicator: some View {
        HStack(spacing: 4) {
            Text(effortLevelText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(effortColor)
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < effortLevelIndex ? effortColor : Color(.systemGray4))
                        .frame(width: 6, height: 14 - CGFloat(index) * 2)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private var effortLevelText: String {
        switch effortLevel.lowercased() {
        case "low": return "Bajo"
        case "medium": return "Medio"
        case "high": return "Alto"
        default: return effortLevel.capitalized
        }
    }
    
    private var effortLevelIndex: Int {
        switch effortLevel.lowercased() {
        case "low": return 1
        case "medium": return 2
        case "high": return 3
        default: return 1
        }
    }
    
    private var effortColor: Color {
        switch effortLevel.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .accentColor
        }
    }
    
    private var effortIcon: String {
        switch effortLevel.lowercased() {
        case "low": return "leaf.fill"
        case "medium": return "flame.fill"
        case "high": return "bolt.fill"
        default: return "gauge"
        }
    }
}

//
//  CalendarFABButton.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import TipKit

struct CalendarFABButton: View {
    let tip: CreateKitFromCalendarTip
    let action: () -> Void
    
    var body: some View {
        Button {
            tip.invalidate(reason: .actionPerformed)
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Fondo circular mínimo para que el glassEffect tenga forma
                Circle()
                    .fill(Color.accentColor.opacity(0.15))

                // Ícono blanco
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56, alignment: .center)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.accentHighlight.opacity(0.5), lineWidth: 0.5)
            )
            .glowShadow(opacity: 0.3, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .popoverTip(tip, arrowEdge: .bottom)
        .fixedSize()
    }
}

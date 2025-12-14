//
//  CardStyle.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct CardStyleModifier: ViewModifier {
    var backgroundColor: Color = .cardBackground
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 14
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Aplica el estilo de tarjeta estándar de la aplicación
    func appCardStyle(backgroundColor: Color = .cardBackground, cornerRadius: CGFloat = 12, padding: CGFloat = 14) -> some View {
        modifier(CardStyleModifier(backgroundColor: backgroundColor, cornerRadius: cornerRadius, padding: padding))
    }
}

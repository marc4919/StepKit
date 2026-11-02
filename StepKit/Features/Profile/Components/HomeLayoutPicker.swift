//
//  HomeLayoutPicker.swift
//  StepKit
//
//  Cómo se abre Mis Kits, elegido viendo el resultado: dos miniaturas de iPhone dibujadas con
//  formas, como en Ajustes > Notificaciones > «Mostrar como».
//

import SwiftUI

struct HomeLayoutPicker: View {
    @Binding var focusLayout: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            option(focus: true,
                   title: String(localized: "Destacado"),
                   hint: String(localized: "Una tarjeta grande con el último Kit que avanzaste y los demás debajo"),
                   identifier: "profile.homeLayout.focus")
            option(focus: false,
                   title: String(localized: "Lista"),
                   hint: String(localized: "Solo la lista de tus Kits"),
                   identifier: "profile.homeLayout.list")
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: focusLayout)
    }

    private func option(focus: Bool, title: String, hint: String, identifier: String) -> some View {
        let selected = focusLayout == focus
        return Button {
            withAnimation(.smooth(duration: 0.3)) { focusLayout = focus }
        } label: {
            VStack(spacing: 10) {
                PhoneMiniature(featured: focus, selected: selected)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(selected ? Color.accentColor : Color.clear, in: .capsule)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// Un iPhone esquemático: con tarjeta grande y filas, o solo filas. Colores del sistema, para modo oscuro.
private struct PhoneMiniature: View {
    let featured: Bool
    let selected: Bool

    private var tint: Color { selected ? .accentColor : Color(.systemGray3) }

    var body: some View {
        VStack(spacing: 5) {
            // Título de la pantalla.
            Capsule()
                .fill(tint.opacity(0.55))
                .frame(width: 30, height: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            if featured {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(selected ? 0.9 : 0.75))
                    .frame(height: 46)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 3) {
                            Capsule().fill(.white.opacity(0.9)).frame(width: 36, height: 4)
                            Capsule().fill(.white.opacity(0.6)).frame(width: 24, height: 3)
                        }
                        .padding(7)
                    }
            }
            ForEach(0..<(featured ? 3 : 6), id: \.self) { _ in
                row
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.top, 14)
        .frame(width: 84, height: 150, alignment: .top)
        .background(Color(.systemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color(.separator), lineWidth: selected ? 2 : 1)
        }
    }

    private var row: some View {
        HStack(spacing: 5) {
            Circle().fill(tint.opacity(0.7)).frame(width: 9, height: 9)
            Capsule().fill(tint.opacity(0.45)).frame(height: 4)
        }
        .padding(.horizontal, 5)
        .frame(height: 15)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 4, style: .continuous))
    }
}

#Preview {
    Form { HomeLayoutPicker(focusLayout: .constant(true)) }
}

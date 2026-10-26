//
//  WelcomeView.swift
//  StepKit
//
//  Bienvenida v4.4: tres páginas antes del acceso. No pide permisos: el aviso de IA
//  aparece al crear el primer Kit y las notificaciones al guardar el primero.
//

import SwiftUI

struct WelcomeView: View {
    var onFinish: () -> Void
    @State private var page = 0
    @State private var artScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titles = [String(localized: "Un objetivo grande.\nUn primer paso claro."),
                          String(localized: "Un plan que puedes ajustar"),
                          String(localized: "Vuelve con un paso claro")]
    private let subtitles = [String(localized: "Da forma a tu idea, avanza a tu ritmo y retoma donde lo dejaste."),
                             String(localized: "Convierte tu idea en pasos claros. Revisa el plan y adáptalo a tu tiempo."),
                             String(localized: "Guarda lo que avanzas y retoma desde donde lo dejaste.")]

    var body: some View {
        VStack(spacing: 0) {
            Text("StepKit")
                .font(.title.bold())
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            TabView(selection: $page) {
                ForEach(0..<3, id: \.self) { index in
                    pageContent(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            PageIndicator(current: page, count: 3)
                .padding(.top, 8)
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    withAnimation(.easeInOut(duration: 0.45)) { onFinish() }
                }
            } label: {
                Group {
                    if page < 2 {
                        Label("Siguiente", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle())
                    } else {
                        Text("Empezar")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .accessibilityIdentifier("onboarding.action")
        }
        .background { EntryBackground() }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            // Pantallas bajas (exterior del iPhone Duo, apaisado): ilustración más pequeña.
            artScale = min(1, max(0.55, (height - 420) / 420))
        }
    }

    /// Las tres páginas comparten estructura y alturas: ilustración animada arriba,
    /// título y texto centrados y tres filas que entran escalonadas.
    private func pageContent(_ index: Int) -> some View {
        let current = page == index
        return ScrollView {
            VStack(spacing: 0) {
                Group {
                    switch index {
                    case 0: OrbitMark(height: artHeight, animated: true)
                    // Con hitos la esfera sube: se dibuja algo más baja para que no se corte.
                    case 1: OrbitMark(height: artHeight * 0.78, milestones: [0.2, 0.42, 0.66], animated: true)
                            .padding(.top, artHeight * 0.18)
                    default: resumeArt(current: current)
                    }
                }
                .frame(height: artHeight)
                .frame(maxWidth: .infinity)
                .id("art-\(index)-\(current)") // vuelve a animar cada vez que la página se muestra
                VStack(spacing: 10) {
                    Text(titles[index])
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitles[index])
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(rows[index].enumerated()), id: \.element.text) { offset, row in
                        WelcomeFeatureRow(symbol: row.symbol, color: row.color, text: row.text,
                                          bounce: current)
                            .opacity(current || reduceMotion ? 1 : 0)
                            .offset(y: current || reduceMotion ? 0 : 14)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                .delay(current ? 0.35 + 0.12 * Double(offset) : 0), value: current)
                    }
                }
                .padding(18)
                .frame(maxWidth: 480)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.7), in: .rect(cornerRadius: 22))
                .padding(.horizontal, 24)
                .padding(.top, 22)
            }
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var artHeight: CGFloat { 240 * artScale }

    private struct Row { let symbol: String; let color: Color; let text: String }

    private var rows: [[Row]] {
        [
            [Row(symbol: Symbols.kits, color: .accentColor, text: String(localized: "Un plan que puedes ajustar")),
             Row(symbol: "checkmark", color: .green, text: String(localized: "Avances que quedan guardados")),
             Row(symbol: Symbols.calendar, color: .purple, text: String(localized: "Tiempo que encaja contigo"))],
            [Row(symbol: "1.circle.fill", color: .accentColor, text: String(localized: "Define lo que quieres conseguir")),
             Row(symbol: "2.circle.fill", color: .accentColor, text: String(localized: "Avanza por pasos con su tiempo y su fecha")),
             Row(symbol: "3.circle.fill", color: .accentColor, text: String(localized: "Confirma que tienes lo que buscabas"))],
            [Row(symbol: Symbols.note, color: .orange, text: String(localized: "Anota lo que has hecho y lo que falta")),
             Row(symbol: Symbols.blocked, color: .red, text: String(localized: "Marca un bloqueo sin perder lo hecho")),
             Row(symbol: "arrow.uturn.forward", color: .green, text: String(localized: "Retoma con un paso concreto"))],
        ]
    }

    private func resumeArt(current: Bool) -> some View {
        ZStack {
            OrbitMark(height: artHeight, animated: true)
            HStack(spacing: 10) {
                IconChip(symbol: Symbols.note, color: .accentColor, size: 30)
                Text(String(localized: "Dos imágenes listas.\nFaltan material y permisos.")).font(.footnote)
            }
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .offset(x: 30, y: artHeight * 0.38)
            .scaleEffect(current || reduceMotion ? 1 : 0.85)
            .opacity(current || reduceMotion ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(current ? 1.0 : 0), value: current)
            .accessibilityHidden(true)
        }
    }
}

struct WelcomeFeatureRow: View {
    var symbol: String
    var color: Color
    var text: String
    /// Cambiarlo hace rebotar el símbolo (efecto nativo de SF Symbols).
    var bounce = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PageIndicator: View {
    var current: Int
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.default, value: current)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Página \(current + 1) de \(count)"))
    }
}

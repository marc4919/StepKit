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

    private let titles = ["Un objetivo grande.\nUn primer paso claro.",
                          "Un plan que puedes ajustar",
                          "Vuelve con un paso claro"]
    private let subtitles = ["Da forma a tu idea, avanza a tu ritmo y retoma donde lo dejaste.",
                             "Convierte tu idea en pasos claros. Revisa el plan y adáptalo a tu tiempo.",
                             "Guarda lo que avanzas y retoma desde donde lo dejaste."]

    var body: some View {
        VStack(spacing: 0) {
            Text("StepKit")
                .font(.title.bold())
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
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

    /// Las tres páginas comparten la misma estructura y alturas: ilustración arriba,
    /// título y texto alineados a la izquierda y tres filas de detalle.
    private func pageContent(_ index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch index {
                    case 0: OrbitMark(height: artHeight)
                    // Con hitos la esfera sube: se dibuja algo más baja para que no se corte.
                    case 1: OrbitMark(height: artHeight * 0.78, milestones: [0.2, 0.42, 0.66])
                            .padding(.top, artHeight * 0.18)
                    default: resumeArt
                    }
                }
                .frame(height: artHeight)
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    Text(titles[index])
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitles[index])
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                VStack(spacing: 14) {
                    ForEach(rows[index], id: \.text) { row in
                        WelcomeFeatureRow(symbol: row.symbol, color: row.color, text: row.text)
                    }
                }
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
            [Row(symbol: Symbols.kits, color: .accentColor, text: "Un plan que puedes ajustar"),
             Row(symbol: "checkmark", color: .green, text: "Avances que quedan guardados"),
             Row(symbol: Symbols.calendar, color: .purple, text: "Tiempo que encaja contigo")],
            [Row(symbol: "1.circle.fill", color: .accentColor, text: "Define lo que quieres conseguir"),
             Row(symbol: "2.circle.fill", color: .accentColor, text: "Avanza por pasos con su tiempo y su fecha"),
             Row(symbol: "3.circle.fill", color: .accentColor, text: "Confirma que tienes lo que buscabas")],
            [Row(symbol: Symbols.note, color: .orange, text: "Anota lo que has hecho y lo que falta"),
             Row(symbol: Symbols.blocked, color: .red, text: "Marca un bloqueo sin perder lo hecho"),
             Row(symbol: "arrow.uturn.forward", color: .green, text: "Retoma con un paso concreto")],
        ]
    }

    private var resumeArt: some View {
        ZStack {
            OrbitMark(height: artHeight)
            HStack(spacing: 10) {
                IconChip(symbol: Symbols.note, color: .accentColor, size: 30)
                Text("Dos imágenes listas.\nFaltan material y permisos.").font(.footnote)
            }
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .offset(x: 30, y: artHeight * 0.38)
            .accessibilityHidden(true)
        }
    }
}

struct WelcomeFeatureRow: View {
    var symbol: String
    var color: Color
    var text: String

    var body: some View {
        HStack(spacing: 14) {
            IconChip(symbol: symbol, color: color, size: 40)
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
        .accessibilityLabel("Página \(current + 1) de \(count)")
    }
}

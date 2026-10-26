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
    @State var page = 0
    @State private var size = CGSize(width: 390, height: 844)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titles = [String(localized: "Un objetivo grande.\nUn primer paso claro."),
                          String(localized: "Un plan que puedes ajustar"),
                          String(localized: "Vuelve con un paso claro")]
    private let subtitles = [String(localized: "Da forma a tu idea, avanza a tu ritmo y retoma donde lo dejaste."),
                             String(localized: "Convierte tu idea en pasos claros. Revisa el plan y adáptalo a tu tiempo."),
                             String(localized: "Guarda lo que avanzas y retoma desde donde lo dejaste.")]

    var body: some View {
        VStack(spacing: 0) {
            // En horizontal muy bajo (Duo cerrado, iPhone) el nombre cede su sitio al contenido.
            if !(wide && size.height < 450) {
                Text("StepKit")
                    .font(.title.bold())
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
            }
            TabView(selection: $page) {
                ForEach(0..<3, id: \.self) { index in
                    pageContent(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Las páginas no se redibujan al cambiar el tamaño de fuera (girar o plegar el Duo):
            // se reconstruyen cuando cambia su maquetación. La página actual se conserva.
            .id("\(wide)-\(short)-\(Int(artHeight))")
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
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .accessibilityIdentifier("onboarding.action")
        }
        .background { EntryBackground() }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    /// Las tres páginas comparten estructura y medidas: la ilustración tiene siempre la misma
    /// altura y el texto reserva el sitio del más largo, así título y filas quedan en el mismo
    /// lugar al pasar de página. En pantallas anchas y apaisadas, ilustración a la izquierda.
    private func pageContent(_ index: Int) -> some View {
        let current = page == index
        return GeometryReader { geo in
            ScrollView {
                Group {
                    if wide {
                        HStack(spacing: 32) {
                            art(index, current: current)
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 0) {
                                texts(index)
                                rowsCard(index, current: current).padding(.top, 18)
                            }
                            .frame(width: textColumnWidth)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        VStack(spacing: 0) {
                            art(index, current: current)
                            texts(index)
                                .padding(.horizontal, 28)
                                .padding(.top, 12)
                            rowsCard(index, current: current)
                                .padding(.horizontal, 24)
                                .padding(.top, short ? 14 : 22)
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private func art(_ index: Int, current: Bool) -> some View {
        Group {
            switch index {
            // La S del logo, en un marco más estrecho que la página: sus extremos ya no se cortan.
            case 0: OrbitMark(height: artHeight, animated: true)
                    .frame(width: artHeight * 1.25)
            case 1: TrailArt(points: WelcomeTrails.plan, milestones: [0.2, 0.75],
                             adjusts: (from: 0.42, to: 0.52), sphereAt: 1)
            default: resumeArt(current: current)
            }
        }
        .frame(height: artHeight)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .id("art-\(index)-\(current)") // vuelve a animar cada vez que la página se muestra
    }

    /// Título y texto de la página encima de los tres textos invisibles: ocupa siempre
    /// la altura del más largo.
    private func texts(_ index: Int) -> some View {
        ZStack(alignment: .top) {
            ForEach(0..<3, id: \.self) { textBlock($0).hidden() }
            textBlock(index)
        }
        .frame(maxWidth: 480)
    }

    private func textBlock(_ index: Int) -> some View {
        VStack(spacing: 10) {
            Text(titles[index])
                .font(size.height < 400 ? .title2.bold() : short ? .title.bold() : .largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitles[index])
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func rowsCard(_ index: Int, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: short ? 10 : 14) {
            ForEach(Array(rows[index].enumerated()), id: \.element.text) { offset, row in
                WelcomeFeatureRow(symbol: row.symbol, color: row.color, text: row.text,
                                  bounce: current)
                    .opacity(current || reduceMotion ? 1 : 0)
                    .offset(y: current || reduceMotion ? 0 : 14)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8)
                        .delay(current ? 0.35 + 0.12 * Double(offset) : 0), value: current)
            }
        }
        .padding(short ? 14 : 18)
        .frame(maxWidth: 480)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.7), in: .rect(cornerRadius: 22))
    }

    /// Ilustración a la izquierda en pantallas anchas y en horizontal bajo (Duo cerrado, iPhone).
    private var wide: Bool {
        TwoColumnLayout.fits(size) || (size.width > size.height * 1.3 && size.height < 500)
    }

    /// Pantallas bajas (exterior del iPhone Duo): título más pequeño para que quepa todo.
    private var short: Bool { size.height < 720 }

    /// La ilustración se adapta al alto y, en dos columnas, al ancho que le queda.
    private var artHeight: CGFloat {
        if wide {
            let column = size.width - 64 - 32 - textColumnWidth
            return max(110, min(240, size.height * 0.45, column / 1.45))
        }
        return max(120, min(240, size.height * (size.height < 640 ? 0.22 : 0.27)))
    }

    private var textColumnWidth: CGFloat { min(440, size.width * 0.5) }

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
            TrailArt(points: WelcomeTrails.loop, sphereAt: 0.93)
            HStack(spacing: 10) {
                IconChip(symbol: Symbols.note, color: .accentColor, size: 30)
                Text(String(localized: "Dos imágenes listas.\nFaltan material y permisos.")).font(.footnote)
            }
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            // Con la ilustración pequeña (Duo cerrado) la nota encoge con ella y no tapa el bucle.
            .scaleEffect(min(1, artHeight / 230), anchor: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 8)
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

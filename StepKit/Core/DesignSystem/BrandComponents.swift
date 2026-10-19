//
//  BrandComponents.swift
//  StepKit
//
//  Identidad v4.4: componentes del sistema primero; la marca vive en el anillo de
//  progreso, en la esfera y en el recorrido curvo del logo.
//

import SwiftUI

// MARK: - Símbolos y colores semánticos

/// Riesgo del Kit: triángulo. Bloqueo de un paso: mano. Nunca el mismo símbolo.
enum Symbols {
    static let risk = "exclamationmark.triangle.fill"
    static let blocked = "hand.raised.fill"
    static let assistant = "text.bubble"
    static let kits = "target"
    static let calendar = "calendar"
    static let profile = "person.crop.circle"
    static let wantedDate = "flag"
    static let time = "clock"
    static let effort = "chart.bar"
    static let note = "note.text"
    static let session = "calendar.badge.clock"
}

/// Colores de metadatos. Siempre acompañados de texto.
enum MetaTint {
    static let time = Color.blue
    static let effort = Color.orange
    static let date = Color.purple
    static let done = Color.green
}

// MARK: - Contenedores

/// Etiqueta corta en mayúsculas sobre un título.
struct Eyebrow: View {
    var text: String
    var color: Color = .accentColor
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

/// Halo azul suave del logo detrás de la cabecera. Se desplaza con el contenido.
struct BrandGlow: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        RadialGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.32 : 0.16), .clear],
                       center: UnitPoint(x: 0.85, y: 0.0), startRadius: 10, endRadius: 420)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// Fondo de pantallas de entrada y estados vacíos: halo del logo.
struct EntryBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.38 : 0.20),
                                    Color.accentColor.opacity(scheme == .dark ? 0.12 : 0.06), .clear],
                           center: UnitPoint(x: 0.6, y: 0.3), startRadius: 10, endRadius: 520)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct TintCard<Content: View>: View {
    var tint: Color = .accentColor
    var strength: Double = 0.09
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(strength), in: .rect(cornerRadius: 22))
    }
}

struct PlainCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }
}

/// Icono en círculo tintado (metadatos, intenciones, campos).
struct IconChip: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 34
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: .circle)
            .accessibilityHidden(true)
    }
}

/// Metadato con color semántico y texto (el color nunca va solo).
struct MetaChip: View {
    var symbol: String
    var text: String
    var color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).foregroundStyle(.primary)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: .capsule)
    }
}

/// Título con el icono detrás (botones «Continuar ›»).
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon.font(.body.weight(.semibold))
        }
    }
}

// MARK: - Progreso y estado

/// Anillo de progreso: pasos completados. Nunca representa el resultado confirmado.
struct ProgressRing: View {
    var done: Int
    var total: Int
    var size: CGFloat = 56
    var showsLabel = true
    @ScaledMetric private var scale: CGFloat = 1

    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: size * 0.11)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: size * min(scale, 1.6), height: size * min(scale, 1.6))
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue("\(done) de \(total) pasos completados")
    }
}

/// Marca pequeña de siguiente acción: un punto sobre un tramo curvo.
struct NextMark: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Path { p in
                p.move(to: CGPoint(x: 2, y: 20))
                p.addQuadCurve(to: CGPoint(x: 20, y: 6), control: CGPoint(x: 14, y: 20))
            }
            .stroke(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            Circle().fill(Color.accentColor).frame(width: 9, height: 9).offset(x: 1, y: 1)
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

// MARK: - Esfera y recorrido del logo

/// Esfera del logo: núcleo cian-azul, brillo especular, borde más oscuro, halo y sombra.
struct BrandSphere: View {
    var size: CGFloat = 64
    var glow = true
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            if glow {
                Circle().fill(Color(red: 0.05, green: 0.47, blue: 1).opacity(scheme == .dark ? 0.75 : 0.40))
                    .frame(width: size * 1.3, height: size * 1.3).blur(radius: size * 0.24)
                Ellipse().fill(Color(red: 0.0, green: 0.32, blue: 0.85).opacity(0.45))
                    .frame(width: size * 0.85, height: size * 0.2).blur(radius: size * 0.07)
                    .offset(y: size * 0.47)
            }
            Circle().fill(RadialGradient(colors: [Color(red: 0.55, green: 0.90, blue: 1.0),
                                                  Color(red: 0.13, green: 0.68, blue: 1.0),
                                                  Color(red: 0.05, green: 0.52, blue: 1.0),
                                                  Color(red: 0.04, green: 0.44, blue: 0.96)],
                                         center: UnitPoint(x: 0.66, y: 0.30), startRadius: 0, endRadius: size * 0.72))
                .frame(width: size, height: size)
            Circle().fill(RadialGradient(colors: [.clear, Color(red: 0, green: 0.15, blue: 0.55).opacity(0.22)],
                                         center: UnitPoint(x: 0.6, y: 0.36), startRadius: size * 0.30, endRadius: size * 0.58))
                .frame(width: size, height: size)
            Ellipse().fill(.white.opacity(0.42))
                .frame(width: size * 0.38, height: size * 0.26).blur(radius: size * 0.08)
                .offset(x: size * 0.16, y: -size * 0.2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Silueta del logo: el recorrido sube desde abajo, llega a la esfera, gira en horquilla
/// y sale hacia arriba a la derecha.
struct OrbitMark: View {
    var height: CGFloat = 160
    var milestones: [CGFloat] = []
    var bloom = false
    @Environment(\.colorScheme) private var scheme

    /// Línea central trazada sobre el icono de la app (normalizada 0–1).
    private static let iconPoints: [CGPoint] = [
        CGPoint(x: 0.15, y: 0.845), CGPoint(x: 0.35, y: 0.77), CGPoint(x: 0.50, y: 0.712),
        CGPoint(x: 0.60, y: 0.668), CGPoint(x: 0.62, y: 0.615), CGPoint(x: 0.51, y: 0.585),
        CGPoint(x: 0.40, y: 0.576), CGPoint(x: 0.31, y: 0.552), CGPoint(x: 0.262, y: 0.507),
        CGPoint(x: 0.275, y: 0.458), CGPoint(x: 0.33, y: 0.418), CGPoint(x: 0.42, y: 0.381),
        CGPoint(x: 0.54, y: 0.342), CGPoint(x: 0.68, y: 0.298), CGPoint(x: 0.83, y: 0.256), CGPoint(x: 0.95, y: 0.224)]
    /// Centro de la esfera, apoyada sobre el tramo inferior.
    private static let iconSphere = CGPoint(x: 0.62, y: 0.585)

    /// Proyecta el icono conservando proporciones.
    private static func map(_ w: CGFloat, _ h: CGFloat) -> (CGPoint) -> CGPoint {
        let scale = h * 1.22
        let ox = w * 0.60 - iconSphere.x * scale
        let oy = h * 0.5 - 0.535 * scale
        return { CGPoint(x: ox + $0.x * scale, y: oy + $0.y * scale) }
    }

    /// Prolonga los extremos hasta los bordes y suaviza con Catmull-Rom → Bézier.
    private static func logoPath(_ w: CGFloat, _ h: CGFloat) -> Path {
        let m = map(w, h)
        var pts = iconPoints.map(m)
        let a0 = pts[1], a1 = pts[0]
        let k0 = (a1.y - a0.y) / (a1.x - a0.x)
        let startX = max(-w * 0.08, a1.x + (h * 0.99 - a1.y) / k0)
        pts.insert(CGPoint(x: startX, y: a1.y + k0 * (startX - a1.x)), at: 0)
        let b0 = pts[pts.count - 2], b1 = pts[pts.count - 1]
        let k1 = (b1.y - b0.y) / (b1.x - b0.x)
        let endX = min(w * 1.08, b1.x + (h * 0.01 - b1.y) / k1)
        pts.append(CGPoint(x: endX, y: b1.y + k1 * (endX - b1.x)))
        return Path { p in
            p.move(to: pts[0])
            for i in 0..<(pts.count - 1) {
                let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
                let t: CGFloat = 1.0 / 6.0
                let c1 = CGPoint(x: p1.x + (p2.x - p0.x) * t, y: p1.y + (p2.y - p0.y) * t)
                let c2 = CGPoint(x: p2.x - (p3.x - p1.x) * t, y: p2.y - (p3.y - p1.y) * t)
                p.addCurve(to: p2, control1: c1, control2: c2)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let path = Self.logoPath(w, h)
            let lw = max(3.5, h * 0.036)
            let sphereSize = h * 0.31
            let junction = Self.map(w, h)(Self.iconSphere)
            let spherePoint = milestones.isEmpty ? junction : point(on: path, at: 0.84)
            ZStack {
                if bloom {
                    RadialGradient(colors: [Color(red: 0.2, green: 0.6, blue: 1).opacity(scheme == .dark ? 0.35 : 0.20), .clear],
                                   center: UnitPoint(x: spherePoint.x / max(w, 1), y: spherePoint.y / max(h, 1)),
                                   startRadius: 0, endRadius: h * 0.75)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.2, green: 0.58, blue: 1).opacity(scheme == .dark ? 0.38 : 0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: h * 0.6))
                    .frame(width: h * 1.2, height: h * 1.2)
                    .position(spherePoint)
                path.stroke(LinearGradient(stops: [.init(color: Color(red: 0.05, green: 0.50, blue: 1.0).opacity(0), location: 0),
                                                   .init(color: Color(red: 0.05, green: 0.50, blue: 1.0), location: 0.2),
                                                   .init(color: Color(red: 0.32, green: 0.70, blue: 1.0), location: 0.55),
                                                   .init(color: Color(red: 0.62, green: 0.85, blue: 1.0).opacity(0.8), location: 0.82),
                                                   .init(color: Color(red: 0.70, green: 0.88, blue: 1.0).opacity(0), location: 1)],
                                           startPoint: .bottomLeading, endPoint: .topTrailing),
                            style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.accentColor.opacity(0.45), radius: lw * 1.2)
                ForEach(milestones, id: \.self) { t in
                    Circle().fill(.white).frame(width: lw * 2.2, height: lw * 2.2)
                        .overlay(Circle().fill(Color.accentColor).padding(lw * 0.5))
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4)
                        .position(point(on: path, at: t))
                }
                BrandSphere(size: sphereSize)
                    .position(x: spherePoint.x, y: spherePoint.y - (milestones.isEmpty ? 0 : sphereSize * 0.32))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func point(on path: Path, at t: CGFloat) -> CGPoint {
        path.trimmedPath(from: 0, to: max(0.001, t)).currentPoint ?? .zero
    }
}

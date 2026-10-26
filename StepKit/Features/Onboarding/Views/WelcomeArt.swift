//
//  WelcomeArt.swift
//  StepKit
//
//  Ilustraciones de la bienvenida. La primera página conserva la S del logo; las otras dos
//  usan recorridos distintos (un ascenso en horizontal y un bucle de vuelta) para no repetir
//  la S que ya aparece en el acceso y al crear un Kit. Todo se dibuja dentro de su marco.
//

import SwiftUI

/// Recorrido con el trazo del logo dibujado dentro de una caja 3:2 centrada en el marco.
/// Los puntos van normalizados (0–1) y se dejan márgenes para la esfera y el grosor del trazo,
/// así nunca toca los bordes de la página.
struct TrailArt: View {
    var points: [CGPoint]
    var milestones: [CGFloat] = []
    /// Un hito que se mueve por el recorrido al aparecer (el plan se ajusta).
    var adjusts: (from: CGFloat, to: CGFloat)? = nil
    /// Posición de la esfera en el recorrido (0–1).
    var sphereAt: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 1
    @State private var appeared = true
    @State private var moved = true
    @State private var floating = false

    var body: some View {
        GeometryReader { geo in
            let box = Self.box(in: geo.size)
            let lw = max(3.5, box.height * 0.04)
            let sphereSize = box.height * 0.26
            let path = Self.path(points, in: box.insetBy(dx: sphereSize * 0.6 + lw, dy: sphereSize * 0.6 + lw))
            let sphere = point(on: path, at: sphereAt)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.2, green: 0.58, blue: 1).opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: box.height * 0.5))
                    .frame(width: box.height, height: box.height)
                    .position(sphere)
                TrailShape(points: points, inset: sphereSize * 0.6 + lw)
                    .trim(from: 0, to: drawn)
                    .stroke(Self.gradient, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.accentColor.opacity(0.4), radius: lw * 1.2)
                ForEach(milestones, id: \.self) { t in
                    milestone(lw).position(point(on: path, at: t))
                        .scaleEffect(appeared ? 1 : 0.01)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.9 * Double(t)), value: appeared)
                }
                if let adjusts {
                    // Hueco que deja el hito al moverse: el plan cambia, lo hecho no se pierde.
                    Circle().strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .frame(width: lw * 2.6, height: lw * 2.6)
                        .position(point(on: path, at: adjusts.from))
                        .opacity(moved ? 1 : 0)
                    milestone(lw)
                        .position(point(on: path, at: moved ? adjusts.to : adjusts.from))
                        .scaleEffect(appeared ? 1 : 0.01)
                }
                BrandSphere(size: sphereSize)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: floating ? -sphereSize * 0.08 : sphereSize * 0.04)
                    .position(x: sphere.x, y: sphere.y - sphereSize * 0.3)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            drawn = 0
            appeared = false
            moved = false
            withAnimation(.easeInOut(duration: 1.1)) { drawn = 1 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.75)) { appeared = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(1.5)) { moved = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.2)) { floating = true }
        }
    }

    private func milestone(_ lw: CGFloat) -> some View {
        Circle().fill(.white).frame(width: lw * 2.6, height: lw * 2.6)
            .overlay(Circle().fill(Color.accentColor).padding(lw * 0.6))
            .shadow(color: Color.accentColor.opacity(0.4), radius: 4)
    }

    private func point(on path: Path, at t: CGFloat) -> CGPoint {
        path.trimmedPath(from: 0, to: max(0.001, min(1, t))).currentPoint ?? .zero
    }

    static let gradient = LinearGradient(
        stops: [.init(color: Color(red: 0.05, green: 0.50, blue: 1.0).opacity(0.15), location: 0),
                .init(color: Color(red: 0.05, green: 0.50, blue: 1.0), location: 0.25),
                .init(color: Color(red: 0.32, green: 0.70, blue: 1.0), location: 0.65),
                .init(color: Color(red: 0.62, green: 0.85, blue: 1.0), location: 1)],
        startPoint: .leading, endPoint: .trailing)

    /// Caja 3:2 lo más grande posible dentro del marco, centrada.
    static func box(in size: CGSize) -> CGRect {
        let w = min(size.width, size.height * 1.5)
        let h = w / 1.5
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Catmull-Rom → Bézier por los puntos normalizados, proyectados en `rect`.
    static func path(_ points: [CGPoint], in rect: CGRect) -> Path {
        let pts = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        return Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for i in 0..<(pts.count - 1) {
                let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
                let t: CGFloat = 1.0 / 6.0
                p.addCurve(to: p2,
                           control1: CGPoint(x: p1.x + (p2.x - p0.x) * t, y: p1.y + (p2.y - p0.y) * t),
                           control2: CGPoint(x: p2.x - (p3.x - p1.x) * t, y: p2.y - (p3.y - p1.y) * t))
            }
        }
    }
}

/// El recorrido como `Shape`, para animar el trazo con `trim`.
private struct TrailShape: Shape {
    var points: [CGPoint]
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let box = TrailArt.box(in: rect.size)
        return TrailArt.path(points, in: box.insetBy(dx: inset, dy: inset))
    }
}

enum WelcomeTrails {
    /// Página 2: una onda que serpentea mientras sube, con tres hitos; el segundo se reajusta.
    /// Se muestrea una curva analítica para que el trazo salga limpio, sin quiebros.
    static let plan: [CGPoint] = (0...60).map { i in
        let x = Double(i) / 60
        let y = 0.8 - 0.6 * x + 0.18 * sin(2 * .pi * 1.5 * x)
        return CGPoint(x: x, y: y)
    }

    /// Página 3: el recorrido da una vuelta completa en lo alto y retoma el camino donde lo dejó
    /// (cicloide alargada: entra y sale en horizontal).
    static let loop: [CGPoint] = {
        let d = 2.6
        let samples = (0...80).map { i -> CGPoint in
            let t = -Double.pi + 2 * .pi * Double(i) / 80
            return CGPoint(x: t - d * sin(t), y: -d * cos(t))
        }
        let lead = 1.2
        let all = [CGPoint(x: -Double.pi - lead, y: d)] + samples + [CGPoint(x: Double.pi + lead, y: d)]
        // Misma escala en los dos ejes (la caja útil es ~1,7 veces más ancha que alta): el bucle sale redondo.
        let width = 2 * (Double.pi + lead), height = 2 * d, aspect = 1.7
        let scale = min(1 / width, 1 / (height * aspect))
        return all.map { CGPoint(x: 0.5 + $0.x * scale, y: 0.5 + $0.y * scale * aspect) }
    }()
}

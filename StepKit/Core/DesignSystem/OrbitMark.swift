//
//  OrbitMark.swift
//  StepKit
//

import SwiftUI

/// Silueta del logo: el recorrido sube desde abajo, llega a la esfera, gira en horquilla
/// y sale hacia arriba a la derecha.
struct OrbitMark: View {
    var height: CGFloat = 160
    var milestones: [CGFloat] = []
    var bloom = false
    /// Dibuja el recorrido al aparecer y deja la esfera flotando. Respeta «Reducir movimiento».
    var animated = false
    /// Si se indica (0…1), la ilustración sigue un progreso externo: la esfera se forma
    /// durante la mayor parte y el recorrido se traza al final.
    var buildProgress: Double? = nil
    /// Con `buildProgress`: la esfera despega hacia arriba (fin de la preparación).
    var liftOff = false
    /// Oculta la esfera sin moverla: otra vista la toma desde aquí (transición a «Tu plan»).
    var hidesSphere = false
    /// 0…1: la esfera retrocede por el recorrido desde su sitio de reposo hasta el inicio de la S
    /// (crear a mano en «Nuevo Kit»: se empieza de cero).
    var travel: CGFloat = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat
    @State private var floating = false
    @State private var appeared: Bool

    init(height: CGFloat = 160, milestones: [CGFloat] = [], bloom: Bool = false, animated: Bool = false,
         buildProgress: Double? = nil, liftOff: Bool = false, hidesSphere: Bool = false, travel: CGFloat = 0) {
        self.travel = travel
        self.height = height
        self.milestones = milestones
        self.bloom = bloom
        self.animated = animated
        self.buildProgress = buildProgress
        self.liftOff = liftOff
        self.hidesSphere = hidesSphere
        // Si va a dibujarse al aparecer, nace sin trazo y con la esfera recogida: empezar dibujada y
        // reiniciar a cero se veía como la S deshaciéndose antes de trazarse.
        _drawn = State(initialValue: animated && buildProgress == nil ? 0 : 1)
        _appeared = State(initialValue: !(animated && buildProgress == nil))
    }

    private var isAnimated: Bool { animated && !reduceMotion }

    /// En modo preparación no hay recorrido: solo la esfera que se forma y despega.
    private var pathFraction: CGFloat {
        buildProgress == nil ? drawn : 0
    }

    private var sphereScale: CGFloat {
        guard let p = buildProgress else { return appeared ? 1 : 0.4 }
        return CGFloat(0.15 + 0.85 * min(1, p)) * (liftOff ? 0.55 : 1)
    }

    private var sphereOpacity: Double {
        if hidesSphere { return 0 }
        guard let p = buildProgress else { return appeared ? 1 : 0 }
        return liftOff ? 0 : min(1, 0.25 + p * 1.5)
    }

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
    fileprivate static func logoPath(_ w: CGFloat, _ h: CGFloat) -> Path {
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
            let restingPoint = milestones.isEmpty ? junction : point(on: path, at: 0.84)
            // En preparación la esfera crece centrada y, al terminar, despega hacia arriba.
            let spherePoint = buildProgress == nil
                ? restingPoint
                : CGPoint(x: w / 2, y: liftOff ? -h * 0.9 : h / 2)
            // La esfera recorre la S: del punto del trazo más cercano a su sitio de reposo hasta donde empieza.
            let rides = buildProgress == nil && milestones.isEmpty
            let restT = rides ? Self.nearestFraction(on: path, to: junction) : 0
            let rideOffset = rides ? CGSize(width: junction.x - point(on: path, at: restT).x,
                                            height: junction.y - point(on: path, at: restT).y) : .zero
            let rideT = restT + (Self.pathStart - restT) * (reduceMotion ? 0 : travel)
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
                    .modifier(OrbitRide(t: rideT, path: path, offset: rideOffset, fixed: rides ? nil : spherePoint))
                    .animation(.smooth(duration: 0.7), value: travel)
                OrbitPathShape().trim(from: 0, to: pathFraction).stroke(LinearGradient(stops: [.init(color: Color(red: 0.05, green: 0.50, blue: 1.0).opacity(0), location: 0),
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
                        .scaleEffect(appeared ? 1 : 0.01)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.75 * Double(t)), value: appeared)
                        .position(point(on: path, at: t))
                }
                BrandSphere(size: sphereSize)
                    .scaleEffect(sphereScale)
                    .opacity(sphereOpacity)
                    .offset(y: floating ? -sphereSize * 0.08 : sphereSize * 0.04)
                    .modifier(OrbitRide(t: rideT, path: path, offset: rideOffset,
                                        fixed: rides ? nil : CGPoint(x: spherePoint.x, y: spherePoint.y - (milestones.isEmpty ? 0 : sphereSize * 0.32))))
                    .animation(.smooth(duration: 0.7), value: travel)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear {
            guard animated, buildProgress == nil else { return }
            if reduceMotion {
                drawn = 1
                appeared = true
                return
            }
            // En el siguiente ciclo, fuera de la transición en la que aparece la vista: dentro de ella
            // la animación del fundido se imponía a estas y la S salía ya hecha.
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 1.1)) { drawn = 1 }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.75)) { appeared = true }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.2)) { floating = true }
            }
        }
    }

    private func point(on path: Path, at t: CGFloat) -> CGPoint {
        path.trimmedPath(from: 0, to: max(0.001, t)).currentPoint ?? .zero
    }

    /// Donde el trazo empieza a verse, abajo a la izquierda.
    private static let pathStart: CGFloat = 0.07

    /// Fracción del trazo (en su primera mitad) que pasa más cerca de un punto.
    private static func nearestFraction(on path: Path, to target: CGPoint) -> CGFloat {
        var best: CGFloat = 0.3, distance = CGFloat.greatestFiniteMagnitude
        for step in 2...50 {
            let t = CGFloat(step) / 100
            guard let p = path.trimmedPath(from: 0, to: t).currentPoint else { continue }
            let d = hypot(p.x - target.x, p.y - target.y)
            if d < distance { distance = d; best = t }
        }
        return best
    }
}

/// Coloca una vista en un punto del recorrido. Es animable: al cambiar `t`, la vista sigue la curva
/// en vez de ir en línea recta.
private struct OrbitRide: ViewModifier, Animatable {
    var t: CGFloat
    let path: Path
    let offset: CGSize
    /// Posición fija, para los usos que no recorren la curva.
    let fixed: CGPoint?

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        if let fixed {
            content.position(fixed)
        } else {
            let p = path.trimmedPath(from: 0, to: max(0.001, t)).currentPoint ?? .zero
            content.position(x: p.x + offset.width, y: p.y + offset.height)
        }
    }
}

/// Recorrido del logo como `Shape`, para poder animar su trazo con `trim`.
private struct OrbitPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        OrbitMark.logoPath(rect.width, rect.height)
    }
}

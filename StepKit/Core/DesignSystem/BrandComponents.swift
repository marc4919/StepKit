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
    static let effort = "cellularbars"
    static let note = "note.text"
    static let session = "calendar.badge.clock"
}

/// Colores de metadatos. Siempre acompañados de texto.
enum MetaTint {
    static let time = Color.blue
    static let effort = Color.orange
    static let repeatTint = time
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
    /// Para símbolos con valor variable (barras de esfuerzo): 0…1.
    var level: Double? = nil
    /// Para textos largos con letra muy grande: el texto parte líneas en vez de salirse de la pantalla.
    var wraps = false
    var body: some View {
        HStack(spacing: 5) {
            // El símbolo es adorno: VoiceOver lo leía aparte («reloj, imagen») antes del dato.
            Image(systemName: symbol, variableValue: level).foregroundStyle(color).accessibilityHidden(true)
            Text(text).foregroundStyle(.primary).lineLimit(wraps ? nil : 1)
        }
        .accessibilityElement(children: .combine)
        .fixedSize(horizontal: !wraps, vertical: wraps)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: wraps ? AnyShape(.rect(cornerRadius: 14)) : AnyShape(.capsule))
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
        // El trazo se dibuja centrado en el borde: la mitad sale del marco. Se le reserva ese sitio
        // para que no lo corte la barra de navegación ni otra vista pegada.
        .padding(size * 0.055)
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue(String(localized: "\(done) de \(total) pasos completados"))
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

/// Icono para un «A tener en cuenta» según de qué trata. Pocas familias y sin alarmas:
/// solo lo que toca a la seguridad conserva el tono de aviso.
enum RiskTopic {
    case time, health, money, safety, mind, material, general

    init(_ text: String) {
        let t = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if has(["seguridad", "peligro", "electric", "corriente", "gas", "fuga", "quemadura", "altura", "toxic", "quimic"]) {
            self = .safety
        } else if has(["salud", "medic", "lesion", "dolor", "cansancio", "agotamiento", "energia", "sueno", "dieta"]) {
            self = .health
        } else if has(["dinero", "coste", "costo", "presupuesto", "gasto", "precio", "deuda", "pago"]) {
            self = .money
        } else if has(["plazo", "tiempo", "minutos", "dias", "semana", "fecha", "ritmo", "horario", "retras"]) {
            self = .time
        } else if has(["motivacion", "perfeccion", "ansiedad", "estres", "constancia", "habito", "frustr", "animo", "olvid"]) {
            self = .mind
        } else if has(["pieza", "material", "herramienta", "ingrediente", "equipo", "manual", "plataforma", "plantilla"]) {
            self = .material
        } else {
            self = .general
        }
    }

    var symbol: String {
        switch self {
        case .time: "clock"
        case .health: "heart"
        case .money: "eurosign.circle"
        case .safety: "exclamationmark.triangle"
        case .mind: "brain.head.profile"
        case .material: "shippingbox"
        case .general: "lightbulb"
        }
    }

    var tint: Color { self == .safety ? .orange : .accentColor }
}

/// Nivel de esfuerzo de un paso para rellenar las barras: bajo, medio o alto.
enum EffortLevel {
    static func fill(_ raw: String) -> Double {
        switch raw.lowercased() {
        case "low", "bajo": 0.2
        case "high", "alto": 1
        default: 0.5
        }
    }
}

//
//  StepKitTips.swift
//  StepKit
//
//  Consejos de primera vez (TipKit). Salen de uno en uno sobre lo que la persona tiene delante,
//  cada uno una sola vez, y el siguiente solo cuando ya ha visto el anterior. Nada de tutorial
//  al abrir la app: lo que hace falta aparece cuando hace falta, y el «?» de cada pantalla lo
//  repite cuando se quiera.
//

import SwiftUI
import TipKit

/// Hitos del primer uso que encadenan los consejos.
struct TipFlow {
    /// Se ha abierto un paso (el consejo de Avance/Atasco/Completar ya se ha podido ver).
    @Parameter static var stepActionsSeen: Bool = false
    /// Se ha entrado en el asistente del Kit.
    @Parameter static var assistantSeen: Bool = false
    /// Se ha guardado el primer avance: ya hay algo que ver en el Registro.
    @Parameter static var firstProgressSaved: Bool = false
}

struct CreateKitTip: Tip {
    var title: Text { Text("Crea tu primer Kit") }
    var message: Text? { Text("Escribe una meta y una fecha. La IA te propone los pasos y los revisas antes de empezar.") }
    var image: Image? { Image(systemName: "plus.circle") }
}

struct StepActionsTip: Tip {
    var title: Text { Text("Tres acciones en cada paso") }
    var message: Text? { Text("Avance guarda lo que llevas. Atasco anota qué te frena. Completar cierra el paso.") }
    var image: Image? { Image(systemName: Symbols.note) }
}

struct KitAssistantTip: Tip {
    var title: Text { Text("Tu asistente del Kit") }
    var message: Text? { Text("Pregúntale cuando no sepas cómo seguir. Si propone cambiar el plan, decides tú.") }
    var image: Image? { Image(systemName: Symbols.assistant) }
    var rules: [Rule] { #Rule(TipFlow.$stepActionsSeen) { $0 } }
}

struct KitLogTip: Tip {
    var title: Text { Text("Tu Registro") }
    var message: Text? { Text("Aquí quedan tus avances, notas y bloqueos, en orden. Las notas del Kit también van aquí.") }
    var image: Image? { Image(systemName: "list.bullet.rectangle") }
    var rules: [Rule] { #Rule(TipFlow.$firstProgressSaved) { $0 } }
}

struct BookSessionTip: Tip {
    var title: Text { Text("Reserva cuándo lo harás") }
    var message: Text? { Text("Elige día y hora para un paso o para algo propio. Te avisa 10 minutos antes.") }
    var image: Image? { Image(systemName: Symbols.session) }
    var rules: [Rule] { #Rule(TipFlow.$assistantSeen) { $0 } }
}

// MARK: - Ayuda de cada pantalla («?»)

/// Qué hace cada cosa de una pantalla, para repasarlo cuando se quiera.
struct HelpTopic: Identifiable {
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    var id: String { title }

    static let kit: [HelpTopic] = [
        HelpTopic(symbol: Symbols.kits, color: .accentColor, title: String(localized: "Plan"),
                  detail: String(localized: "Los pasos, en orden y con fecha. Toca uno para abrirlo.")),
        HelpTopic(symbol: "list.bullet.rectangle", color: .orange, title: String(localized: "Registro"),
                  detail: String(localized: "Tus avances, notas y bloqueos, en orden. Las notas del Kit también van aquí.")),
        HelpTopic(symbol: Symbols.assistant, color: .blue, title: String(localized: "Asistente"),
                  detail: String(localized: "Pregúntale cuando no sepas cómo seguir. Si propone cambiar el plan, decides tú.")),
        HelpTopic(symbol: "info.circle", color: .gray, title: String(localized: "Detalles"),
                  detail: String(localized: "La meta, la fecha y los recordatorios del Kit. Desde ahí se edita.")),
    ]

    static let step: [HelpTopic] = [
        HelpTopic(symbol: "checkmark.circle", color: .green, title: String(localized: "Al terminar"),
                  detail: String(localized: "Qué queda hecho cuando acabas el paso.")),
        HelpTopic(symbol: Symbols.note, color: .accentColor, title: String(localized: "Avance"),
                  detail: String(localized: "Guarda lo que llevas, aunque no hayas terminado.")),
        HelpTopic(symbol: "hand.raised", color: .red, title: String(localized: "Atasco"),
                  detail: String(localized: "Anota qué te frena. El asistente puede ayudarte a salir.")),
        HelpTopic(symbol: "checkmark", color: .green, title: String(localized: "Completar"),
                  detail: String(localized: "Cierra el paso y pasa al siguiente.")),
        HelpTopic(symbol: Symbols.session, color: .teal, title: String(localized: "Reservar sesión"),
                  detail: String(localized: "Desde el Calendario, elige cuándo harás el paso. Te avisa 10 minutos antes.")),
        HelpTopic(symbol: "pencil", color: .purple, title: String(localized: "Editar"),
                  detail: String(localized: "Cambia el título, la descripción, la fecha o el tiempo del paso.")),
    ]
}

/// Un bloque de la hoja de ayuda: el Kit, el paso.
struct HelpSection: Identifiable {
    let title: String
    let topics: [HelpTopic]
    var id: String { title }
}

extension HelpTopic {
    static let all: [HelpSection] = [
        HelpSection(title: String(localized: "En el Kit"), topics: kit),
        HelpSection(title: String(localized: "En cada paso"), topics: step),
    ]
}

struct HelpSheet: View {
    let title: String
    let sections: [HelpSection]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.topics) { topic in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title)
                                    Text(topic.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                IconChip(symbol: topic.symbol, color: topic.color, size: 30)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // Sin «Listo»: la hoja se cierra deslizando, como las demás hojas de ayuda.
            // El título como elemento principal: en el Duo cerrado el sistema lo pega a la izquierda.
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Botón «?» del Kit: abre la ayuda del Kit y del paso.
struct HelpButton: View {
    @State private var showing = false

    var body: some View {
        Button("Ayuda", systemImage: "questionmark.circle") { showing = true }
            .sheet(isPresented: $showing) {
                HelpSheet(title: String(localized: "Qué hay en un Kit y en un paso"), sections: HelpTopic.all)
            }
            .accessibilityHint("Explica qué hace cada cosa del Kit y de sus pasos")
            .accessibilityIdentifier("kit.help")
    }
}

// MARK: - Cómo funciona StepKit (Perfil)

struct HowItWorksView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    IconChip(symbol: "questionmark.circle.fill", color: .purple, size: 44)
                    Text("Cómo funciona StepKit").font(.largeTitle.bold())
                    Text("Cuatro ideas y ya está. Lo demás lo descubres usándola.").foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            section(String(localized: "Un Kit es una meta con plan"),
                    String(localized: "Escribes qué quieres conseguir y para cuándo. La IA propone los pasos y los revisas antes de aceptar."),
                    Array(HelpTopic.kit.prefix(2)))
            section(String(localized: "Un paso es una acción concreta"),
                    String(localized: "Tiene qué hacer, cuánto tarda y qué día toca. Lo abres y trabajas en él."),
                    Array(HelpTopic.step.prefix(4)))
            section(String(localized: "El asistente te acompaña"),
                    String(localized: "Habla con él desde el Kit o desde un paso. Si algo no encaja, propone cambios y tú decides."),
                    [])
            section(String(localized: "El Calendario es tu tiempo"),
                    String(localized: "Reserva cuándo harás un paso o algo propio. Cada mañana, un solo aviso con lo que toca."),
                    [])
        }
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ text: String, _ topics: [HelpTopic]) -> some View {
        Section {
            Text(text).foregroundStyle(.secondary)
            ForEach(topics) { topic in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic.title)
                        Text(topic.detail).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    IconChip(symbol: topic.symbol, color: topic.color, size: 28)
                }
            }
        } header: {
            Text(title)
        }
    }
}

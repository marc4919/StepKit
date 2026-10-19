//
//  DesignFixtures.swift
//  StepKit
//
//  Solo DEBUG. `-StepKitDesignFixtures <escenario>` abre la app con datos ficticios
//  en memoria, sin sesión, red ni sync, para revisar la maquetación v4.4 en el simulador.
//

#if DEBUG
import SwiftUI
import SwiftData

enum DesignFixtureScenario: String {
    case kits          // varios Kits en curso
    case one           // un solo Kit
    case empty         // sin Kits
    case completed     // un Kit con todos los pasos terminados
    case step          // paso 2 del portfolio, en curso
    case blocked       // paso 2 del portfolio, bloqueado

    static let argument = "-StepKitDesignFixtures"

    static var current: DesignFixtureScenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: argument), args.indices.contains(index + 1) else { return nil }
        return DesignFixtureScenario(rawValue: args[index + 1])
    }
}

struct DesignFixtureRoot: View {
    let scenario: DesignFixtureScenario
    @State private var container: ModelContainer
    @State private var viewModel = KitsViewModel()

    init(scenario: DesignFixtureScenario) {
        self.scenario = scenario
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, configurations: config)
        DesignFixtureData.seed(scenario, into: container.mainContext)
        _container = State(initialValue: container)
    }

    var body: some View {
        TabView {
            Tab("Kits", systemImage: Symbols.kits) {
                if scenario == .step || scenario == .blocked, let step = portfolioStep {
                    NavigationStack { StepDetailView(stepEntity: step, stepNumber: 2) }
                } else {
                    kits
                }
            }
            Tab("Calendario", systemImage: Symbols.calendar) { Text("Calendario") }
            Tab("Asistente", systemImage: Symbols.assistant) { Text("Asistente") }
            Tab("Perfil", systemImage: Symbols.profile) { Text("Perfil") }
            Tab(role: .search) { Text("Buscar") }
        }
        .modelContainer(container)
    }

    private var portfolioStep: StepEntity? {
        let kits = (try? container.mainContext.fetch(FetchDescriptor<GoalEntity>())) ?? []
        return kits.first?.orderedActiveSteps.dropFirst().first
    }

    private var kits: some View {
        let all = (try? container.mainContext.fetch(FetchDescriptor<GoalEntity>())) ?? []
        return KitsListCompactView(
            activeKits: all.filter { !$0.isCompleted },
            completedKits: all.filter(\.isCompleted),
            kitEntities: all,
            viewModel: viewModel
        )
    }
}

@MainActor
enum DesignFixtureData {
    static func seed(_ scenario: DesignFixtureScenario, into context: ModelContext) {
        switch scenario {
        case .empty:
            break
        case .one, .step:
            insertPortfolio(into: context, blocked: false)
        case .blocked:
            insertPortfolio(into: context, blocked: true)
        case .kits:
            insertPortfolio(into: context, blocked: false)
            insert(kit("Taller de fotografía", done: 2, of: 6, next: "Pedir presupuesto de la sala", inDays: 40, ago: 3), into: context)
            insert(kit("Huerto en el balcón", done: 1, of: 5, next: "Elegir semillas de temporada", inDays: 55, ago: 8), into: context)
            insert(kit("Preparar la media maratón", done: 4, of: 9, next: "Rodaje largo de 14 km", inDays: 70, ago: 12), into: context)
        case .completed:
            insert(kit("Mi portfolio", done: 7, of: 7, next: "", inDays: 20, ago: 1), into: context)
        }
    }

    private static func insertPortfolio(into context: ModelContext, blocked: Bool) {
        let item = portfolio()
        insert(item, into: context)
        let step = item.1[1]
        let noted = Date.now.addingTimeInterval(-86_400 * 2)
        context.insert(ProgressEntryEntity(
            ownerID: step.ownerID, kitID: item.0.id, stepID: step.id, kind: .progress,
            note: "Dos imágenes listas. Faltan material y permisos.", notedAt: noted,
            createdAt: noted, updatedAt: noted
        ))
        if blocked {
            step.blockedReason = "Me falta permiso para usar una captura del segundo caso."
            step.blockedAt = .now.addingTimeInterval(-3_600)
        }
    }

    private static func portfolio() -> (GoalEntity, [StepEntity]) {
        let titles = [
            ("Elegir tres proyectos", "Selecciona los tres casos que mejor muestran tu trabajo.", 30, "low"),
            ("Inventariar material y permisos", "Una lista de recursos de cada caso y su autorización comprobada.", 25, "medium"),
            ("Escribir el caso principal", "Contexto, tu aportación y el resultado del primer caso.", 60, "high"),
            ("Escribir los otros dos casos", "Mismo formato, más breves.", 90, "medium"),
            ("Montar la web", "Plantilla sencilla con los tres casos y contacto.", 120, "high"),
            ("Pedir una revisión", "Una persona de confianza revisa textos y enlaces.", 20, "low"),
            ("Publicar y compartir", "Publica y envía el enlace a tres contactos.", 15, "low"),
        ]
        let kit = GoalEntity(planTitle: "Publicar mi portfolio", horizonDays: 40,
                             kpi: "Portfolio publicado con tres casos",
                             updatedAt: .now.addingTimeInterval(-86_400))
        let steps = titles.enumerated().map { index, item in
            StepEntity(stepTitle: item.0, descriptionShort: item.1, descriptionLong: item.1,
                       estimateMinutes: item.2,
                       suggestedDeadline: Calendar.current.date(byAdding: .day, value: 4 + index * 5, to: .now),
                       effortLevel: item.3, order: index, isCompleted: index == 0,
                       updatedAt: .now.addingTimeInterval(-86_400))
        }
        return (kit, steps)
    }

    private static func kit(_ title: String, done: Int, of total: Int, next: String,
                            inDays: Int, ago: Int) -> (GoalEntity, [StepEntity]) {
        let updated = Date.now.addingTimeInterval(TimeInterval(-ago * 86_400))
        let kit = GoalEntity(planTitle: title, horizonDays: inDays, kpi: title, updatedAt: updated)
        let steps = (0..<total).map { index in
            StepEntity(stepTitle: index == done ? next : "Paso \(index + 1)",
                       descriptionShort: "", descriptionLong: "", estimateMinutes: 30,
                       suggestedDeadline: Calendar.current.date(byAdding: .day, value: inDays * (index + 1) / total, to: .now),
                       order: index, isCompleted: index < done, updatedAt: updated)
        }
        return (kit, steps)
    }

    private static func insert(_ item: (GoalEntity, [StepEntity]), into context: ModelContext) {
        context.insert(item.0)
        for step in item.1 {
            context.insert(step)
            step.goal = item.0
        }
        item.0.progress = item.0.computedProgress
    }
}
#endif

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
    case confirmed     // un Kit terminado con el resultado confirmado y otro pendiente
    case calendar      // pestaña Calendario con sesiones reservadas
    case assistant     // pestaña Asistente
    case kit           // plan del portfolio
    case welcome       // bienvenida
    case calendarEmpty // Calendario sin Kits
    case create        // formulario Crear Kit
    case signIn        // acceso

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
    @State private var authManager: AuthManager
    @State private var tab: Int

    init(scenario: DesignFixtureScenario) {
        self.scenario = scenario
        let suite = "StepKit.DesignFixtures"
        UserDefaults().removePersistentDomain(forName: suite)
        let auth = AuthManager(keychain: DesignFixtureKeychain(), preferences: UserDefaults(suiteName: suite) ?? .standard)
        auth.saveAuth(token: "design-fixtures",
                      user: UserInfo(id: DesignFixtureData.owner, tier: "premium",
                                     monthlyTokensUsed: 0, monthlyTokenQuota: 10_000))
        _authManager = State(initialValue: auth)
        _tab = State(initialValue: [.calendar, .calendarEmpty].contains(scenario) ? 1 : scenario == .assistant ? 2 : 0)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, WorkSessionEntity.self, configurations: config)
        DesignFixtureData.seed(scenario, into: container.mainContext)
        _container = State(initialValue: container)
    }

    var body: some View {
        if scenario == .welcome {
            WelcomeView {}
        } else if scenario == .signIn {
            SignInView().environment(authManager)
        } else if scenario == .create {
            KitCreatorView()
                .environment(authManager)
                .environment(AIConsentManager())
                .modelContainer(container)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Kits", systemImage: Symbols.kits, value: 0) {
                if scenario == .step || scenario == .blocked, let step = portfolioStep {
                    NavigationStack { StepDetailView(stepEntity: step, stepNumber: 2) }
                } else if scenario == .kit, let kit = portfolioStep?.goal {
                    NavigationStack { KitDetailView(kitEntity: kit) }
                } else {
                    kits
                }
            }
            Tab("Calendario", systemImage: Symbols.calendar, value: 1) { CalendarPlusView() }
            Tab("Asistente", systemImage: Symbols.assistant, value: 2) { TrainerView() }
            Tab("Perfil", systemImage: Symbols.profile, value: 3) { Text("Perfil") }
            Tab(value: 4, role: .search) { Text("Buscar") }
        }
        .tabViewStyle(.sidebarAdaptable)
        .modelContainer(container)
        .environment(authManager)
        .environment(AIConsentManager())
    }

    private var portfolioStep: StepEntity? {
        let kits = (try? container.mainContext.fetch(FetchDescriptor<GoalEntity>())) ?? []
        return kits.first?.orderedActiveSteps.dropFirst().first
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    @ViewBuilder private var kits: some View {
        let all = (try? container.mainContext.fetch(FetchDescriptor<GoalEntity>())) ?? []
        if sizeClass == .regular {
            KitsListRegularView(
                activeKits: all.filter { !$0.isCompleted },
                completedKits: all.filter(\.isCompleted),
                kitEntities: all,
                viewModel: viewModel
            )
        } else {
            KitsListCompactView(
                activeKits: all.filter { !$0.isCompleted },
                completedKits: all.filter(\.isCompleted),
                kitEntities: all,
                viewModel: viewModel
            )
        }
    }
}

@MainActor
enum DesignFixtureData {
    static let owner = "design-fixtures"

    static func seed(_ scenario: DesignFixtureScenario, into context: ModelContext) {
        defer { claimAll(in: context) }
        switch scenario {
        case .empty, .welcome, .calendarEmpty, .create, .signIn:
            break
        case .one, .step, .kit:
            insertPortfolio(into: context, blocked: false)
        case .blocked:
            insertPortfolio(into: context, blocked: true)
        case .calendar, .assistant:
            insertPortfolio(into: context, blocked: false)
            insert(kit("Taller de fotografía", done: 2, of: 6, next: "Pedir presupuesto de la sala", inDays: 40, ago: 3), into: context)
            insertSessions(into: context)
        case .kits:
            insertPortfolio(into: context, blocked: false)
            insert(kit("Taller de fotografía", done: 2, of: 6, next: "Pedir presupuesto de la sala", inDays: 40, ago: 3), into: context)
            insert(kit("Huerto en el balcón", done: 1, of: 5, next: "Elegir semillas de temporada", inDays: 55, ago: 8), into: context)
            insert(kit("Preparar la media maratón", done: 4, of: 9, next: "Rodaje largo de 14 km", inDays: 70, ago: 12), into: context)
        case .completed:
            insert(kit("Mi portfolio", done: 7, of: 7, next: "", inDays: 20, ago: 1), into: context)
        case .confirmed:
            insert(kit("Mi portfolio", done: 7, of: 7, next: "", inDays: 20, ago: 1), into: context)
            let done = kit("Huerto en el balcón", done: 5, of: 5, next: "", inDays: 10, ago: 9)
            done.0.resultConfirmedAt = .now.addingTimeInterval(-86_400 * 9)
            insert(done, into: context)
        }
    }

    /// Todo pertenece a la cuenta ficticia para que las vistas filtradas por propietario lo muestren.
    private static func claimAll(in context: ModelContext) {
        try? context.fetch(FetchDescriptor<GoalEntity>()).forEach { $0.ownerID = owner }
        try? context.fetch(FetchDescriptor<StepEntity>()).forEach { $0.ownerID = owner }
        try? context.fetch(FetchDescriptor<ProgressEntryEntity>()).forEach { $0.ownerID = owner }
        try? context.fetch(FetchDescriptor<WorkSessionEntity>()).forEach { $0.ownerID = owner }
    }

    private static func insertSessions(into context: ModelContext) {
        let kits = (try? context.fetch(FetchDescriptor<GoalEntity>())) ?? []
        guard let portfolio = kits.first(where: { $0.title == "Publicar mi portfolio" }),
              let step = portfolio.nextStep else { return }
        let calendar = Calendar.current
        let today18 = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
        let saturday = calendar.date(byAdding: .day, value: 4, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now) ?? .now
        context.insert(WorkSessionEntity(ownerID: owner, kitID: portfolio.id, stepID: step.id,
                                         startsAt: today18, durationMinutes: 15))
        context.insert(WorkSessionEntity(ownerID: owner, kitID: portfolio.id, stepID: step.id,
                                         startsAt: saturday, durationMinutes: 30))
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

private final class DesignFixtureKeychain: KeychainStoring {
    private var values: [String: Data] = [:]

    func save<T: Codable>(_ value: T, forKey key: String) throws {
        values[key] = try JSONEncoder().encode(value)
    }

    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = values[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func saveString(_ value: String, forKey key: String) throws {
        values[key] = Data(value.utf8)
    }

    func getString(forKey key: String) throws -> String? {
        values[key].flatMap { String(data: $0, encoding: .utf8) }
    }

    func delete(forKey key: String) throws {
        values.removeValue(forKey: key)
    }
}
#endif

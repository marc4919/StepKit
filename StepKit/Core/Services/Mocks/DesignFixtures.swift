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
    case assistant     // asistente del Kit: lista de conversaciones
    case assistantKit  // Kit con el acceso al asistente
    case assistantStep // paso 3 con «Ayúdame con este paso»
    case assistantChat // asistente abierto desde el paso 3
    case assistantProposal // propuesta: mover el paso 3 obliga a mover el 4
    case kit           // plan del portfolio
    case welcome       // bienvenida
    case calendarEmpty // Calendario sin Kits
    case create        // formulario Crear Kit
    case questions     // Kit delicado: preguntas antes de preparar el plan
    case careful       // preparando un Kit delicado: pantalla de cuidado y reinicio con «Ajustando tu plan…»
    case signIn        // acceso
    case profile       // pestaña Perfil

    static let argument = "-StepKitDesignFixtures"

    var isAssistant: Bool {
        [.assistant, .assistantKit, .assistantStep, .assistantChat, .assistantProposal].contains(self)
    }

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
        auth.updateDisplayName("Alex Martín")
        _authManager = State(initialValue: auth)
        _tab = State(initialValue: [.calendar, .calendarEmpty].contains(scenario) ? 1 : scenario == .profile ? 3 : 0)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, ProgressEntryEntity.self, WorkSessionEntity.self, configurations: config)
        DesignFixtureData.seed(scenario, into: container.mainContext)
        if scenario.isAssistant {
            DesignFixtureData.seedConversations(in: container.mainContext)
        }
        _container = State(initialValue: container)
    }

    var body: some View {
        if scenario == .welcome {
            WelcomeView {}
        } else if scenario == .signIn {
            SignInView().environment(authManager)
        } else if scenario == .careful || scenario == .questions {
            CarefulCreationPreview(asksQuestions: scenario == .questions)
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
                } else if scenario == .kit || scenario == .assistantKit, let kit = portfolioStep?.goal {
                    NavigationStack { KitDetailView(kitEntity: kit) }
                } else if scenario == .assistant, let kit = portfolioStep?.goal {
                    NavigationStack { KitAssistantHubView(kit: kit) }
                } else if scenario == .assistantStep, let step = portfolioStep3 {
                    NavigationStack { StepDetailView(stepEntity: step, stepNumber: 3) }
                } else if scenario == .assistantChat, let step = portfolioStep3, let kit = step.goal {
                    NavigationStack {
                        KitAssistantChatView(kit: kit, conversation: DesignFixtureData.freshStepConversation(kit: kit, step: step))
                    }
                } else if scenario == .assistantProposal, let step = portfolioStep3, let kit = step.goal {
                    NavigationStack {
                        KitAssistantChatView(kit: kit, conversation: KitAssistantStore.shared.conversation(kit: kit, step: step))
                    }
                } else {
                    kits
                }
            }
            Tab("Calendario", systemImage: Symbols.calendar, value: 1) { CalendarPlusView() }
            Tab("Perfil", systemImage: Symbols.profile, value: 3) { ProfileView() }
            Tab(value: 4, role: .search) { SearchView { tab = 0 } }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSearchActivation(.searchTabSelection)
        .modelContainer(container)
        .environment(authManager)
        .environment(AIConsentManager())
    }

    private var portfolioStep3: StepEntity? {
        let kits = (try? container.mainContext.fetch(FetchDescriptor<GoalEntity>())) ?? []
        return kits.first { $0.title == "Publicar mi portfolio" }?.orderedActiveSteps.dropFirst(2).first
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

/// Simula los eventos del servidor para un Kit delicado: plan_mode, título tardío, reinicio y pasos.
private struct CarefulCreationPreview: View {
    var asksQuestions = false
    @State private var state = KitStreamingState()

    var body: some View {
        KitCreationStreamingProgress(streamingState: $state, onSave: {}, onDiscard: {},
                                     onAnswer: { _ in state.pendingQuestions = []; Task { await play(afterAnswers: true) } },
                                     onSkipQuestions: { state.pendingQuestions = []; Task { await play(afterAnswers: true) } })
            .task {
                if asksQuestions {
                    state.handleEvent(event("plan_mode", mode: "careful", reasons: ["substances", "health"]))
                    try? await Task.sleep(for: .seconds(1))
                    var questions = event("questions")
                    questions.questions = [
                        KitQuestion(id: "q1", text: "¿Cuánto fumas ahora al día?", kind: .single,
                                    options: ["Menos de 5", "Entre 5 y 15", "Más de 15"]),
                        KitQuestion(id: "q2", text: "¿Qué te ayudaría más?", kind: .multi,
                                    options: ["Apoyo médico", "Una app de seguimiento", "Hacer deporte"]),
                        KitQuestion(id: "q3", text: "¿Lo has intentado antes? Cuéntame qué pasó.", kind: .text, options: [])
                    ]
                    state.handleEvent(questions)
                } else {
                    await play()
                }
            }
    }

    private func event(_ type: String, title: String? = nil, step: Int? = nil,
                       mode: String? = nil, reasons: [String]? = nil) -> AIChatStreamEvent {
        AIChatStreamEvent(type: type, mode: mode, reasons: reasons,
                          kitTitle: title, kpi: title == nil ? nil : "Correr 5 km sin parar",
                          horizonDays: title == nil ? nil : 45, risks: nil,
                          step: step.map { index in
                              StreamStepOutput(stepTitle: "Paso \(index + 1)",
                                               description: StreamDescriptionOutput(short: "Corto", long: "Largo"),
                                               estimateMinutes: 20, suggestedDeadline: "2026-11-10",
                                               effortLevel: "low", adaptsTo: "", blockedByPremium: false)
                          },
                          stepIndex: step, totalSteps: nil, kitId: nil, kit: nil, usage: nil, error: nil)
    }

    private func play(afterAnswers: Bool = false) async {
        if !afterAnswers {
            state.handleEvent(event("plan_mode", mode: "careful", reasons: ["health", "tight_deadline"]))
        }
        try? await Task.sleep(for: .seconds(6))
        state.handleEvent(event("kit_info", title: "Volver a correr"))
        try? await Task.sleep(for: .seconds(2))
        state.handleEvent(event("step", step: 0))
        try? await Task.sleep(for: .seconds(2))
        state.handleEvent(event("restart"))
        try? await Task.sleep(for: .seconds(5))
        state.handleEvent(event("kit_info", title: "Volver a correr"))
        for index in 0..<4 {
            try? await Task.sleep(for: .seconds(1))
            state.handleEvent(event("step", step: index))
        }
        try? await Task.sleep(for: .seconds(1))
        state.handleEvent(event("done"))
    }
}

@MainActor
enum DesignFixtureData {
    static let owner = "design-fixtures"

    static func seed(_ scenario: DesignFixtureScenario, into context: ModelContext) {
        defer { claimAll(in: context) }
        switch scenario {
        case .empty, .welcome, .calendarEmpty, .create, .careful, .questions, .signIn:
            break
        case .one, .step, .kit:
            insertPortfolio(into: context, blocked: false)
        case .blocked:
            insertPortfolio(into: context, blocked: true)
        case .assistant, .assistantKit, .assistantStep, .assistantChat, .assistantProposal:
            insertPortfolio(into: context, blocked: true)
            if let kit = try? context.fetch(FetchDescriptor<GoalEntity>()).first,
               let step3 = kit.orderedActiveSteps.dropFirst(2).first {
                let noted = Date.now.addingTimeInterval(-86_400)
                context.insert(ProgressEntryEntity(
                    ownerID: owner, kitID: kit.id, stepID: step3.id, kind: .progress,
                    note: "Borrador del contexto escrito; falta el resultado.", notedAt: noted,
                    createdAt: noted, updatedAt: noted))
            }
        case .calendar, .profile:
            insertPortfolio(into: context, blocked: false)
            insert(kit("Taller de fotografía", done: 2, of: 6, next: "Pedir presupuesto de la sala", inDays: 40, ago: 3), into: context)
            insertSessions(into: context)
        case .kits:
            // Escenario completo: varios Kits, registro, un bloqueo, sesiones y un Kit terminado.
            insertPortfolio(into: context, blocked: false)
            let photo = kit("Taller de fotografía", done: 2, of: 6, next: "Pedir presupuesto de la sala", inDays: 40, ago: 3)
            insert(photo, into: context)
            insert(kit("Huerto en el balcón", done: 1, of: 5, next: "Elegir semillas de temporada", inDays: 55, ago: 8), into: context)
            insert(kit("Preparar la media maratón", done: 4, of: 9, next: "Rodaje largo de 14 km", inDays: 70, ago: 12), into: context)
            let english = kit("Repasar inglés para entrevistas", done: 6, of: 6, next: "", inDays: 10, ago: 20)
            english.0.resultConfirmedAt = .now.addingTimeInterval(-86_400 * 18)
            insert(english, into: context)
            let blockedStep = photo.1[2]
            blockedStep.blockedReason = "Espero respuesta del centro cívico sobre la sala."
            blockedStep.blockedAt = .now.addingTimeInterval(-86_400)
            let noted = Date.now.addingTimeInterval(-86_400 * 3)
            context.insert(ProgressEntryEntity(
                ownerID: owner, kitID: photo.0.id, stepID: photo.1[1].id, kind: .progress,
                note: "Lista de material terminada: cámaras, trípodes y fondos.", notedAt: noted,
                createdAt: noted, updatedAt: noted))
            context.insert(ProgressEntryEntity(
                ownerID: owner, kitID: photo.0.id, stepID: blockedStep.id, kind: .blocked,
                note: blockedStep.blockedReason ?? "", notedAt: .now.addingTimeInterval(-86_400),
                createdAt: .now, updatedAt: .now))
            insertSessions(into: context)
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

    /// Conversaciones de ejemplo del asistente del Kit «Publicar mi portfolio».
    /// El init de la raíz se repite en cada evaluación de la escena: se siembra una sola vez
    /// para no provocar un bucle de actualizaciones del store observado.
    private static var didSeedConversations = false

    static func seedConversations(in context: ModelContext) {
        guard !didSeedConversations else { return }
        didSeedConversations = true
        let store = KitAssistantStore.shared
        store.removeAll()
        guard let kit = try? context.fetch(FetchDescriptor<GoalEntity>()).first(where: { $0.title == "Publicar mi portfolio" }),
              let step3 = kit.orderedActiveSteps.dropFirst(2).first else { return }
        let general = store.newConversation(kit: kit, title: "¿Dónde lo dejamos?")
        general.viewModel.messages = [
            ChatMessage(sender: .user, text: "¿Dónde lo dejamos?", timestamp: .now.addingTimeInterval(-86_400 * 2)),
            ChatMessage(sender: .assistant, text: "Tienes elegidos los tres proyectos. En el inventario te falta el permiso de una captura del segundo caso; mientras llega, puedes avanzar el caso principal.", timestamp: .now.addingTimeInterval(-86_400 * 2)),
        ]
        let stepConversation = store.conversation(kit: kit, step: step3)
        stepConversation.viewModel.messages = [
            ChatMessage(sender: .user, text: "Este paso ya no encaja", timestamp: .now.addingTimeInterval(-600)),
            ChatMessage(sender: .assistant, text: "Esta semana tienes menos tiempo del previsto. Te propongo mover el caso principal unos días; para mantener el orden, el siguiente caso también se mueve. Revisa la propuesta antes de aplicarla.", timestamp: .now.addingTimeInterval(-590)),
        ]
        if let proposal = PlanProposalBuilder.moveStep(step3, in: kit) {
            stepConversation.proposals = [proposal]
        }
    }

    /// Conversación nueva (sin mensajes) del paso, para enseñar el inicio del asistente.
    private static var freshConversation: KitConversation?

    static func freshStepConversation(kit: GoalEntity, step: StepEntity) -> KitConversation {
        if let freshConversation { return freshConversation }
        let created = KitConversation(kitID: kit.id, stepID: step.id, title: "Paso \(kit.position(of: step)) · \(step.stepTitle)")
        freshConversation = created
        return created
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
            ("Repasar los textos en voz alta", "Lee un caso en voz alta y corrige lo que suene raro.", 15, "low"),
            ("Publicar y compartir", "Publica y envía el enlace a tres contactos.", 15, "low"),
        ]
        let kit = GoalEntity(planTitle: "Publicar mi portfolio", horizonDays: 40,
                             kpi: "Portfolio publicado con tres casos",
                             updatedAt: .now.addingTimeInterval(-86_400))
        let steps = titles.enumerated().map { index, item in
            StepEntity(stepTitle: item.0, descriptionShort: item.1, descriptionLong: item.1,
                       estimateMinutes: item.2,
                       suggestedDeadline: Calendar.current.date(byAdding: .day, value: [4, 9, 12, 15, 23, 29, 34][index], to: .now),
                       effortLevel: item.3, order: index, isCompleted: index == 0,
                       updatedAt: .now.addingTimeInterval(-86_400))
        }
        // Un hábito: el repaso se repite cada día, cinco veces.
        steps[5].repeatEvery = "day"
        steps[5].repeatTimes = 5
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

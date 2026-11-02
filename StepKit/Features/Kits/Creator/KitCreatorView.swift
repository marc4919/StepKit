//
//  KitCreatorView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared Types

// Moved to KitCreatorViewModel.swift or kept here if needed for FocusState
// Defining here to ensure availability if not strictly imported
enum KitCreatorField: Hashable {
    case description, obstacles, time, doneWhen, startingPoint
}

// MARK: - Main View

struct KitCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @Environment(AIConsentManager.self) private var consentManager

    // Callback cuando se crea un kit exitosamente
    var onKitCreated: ((Goal) -> Void)?

    // Fecha inicial opcional (para cuando se abre desde el calendario)
    var initialDate: Date?
    @State private var confirmingDiscard = false
    @State private var consentDeclined = false

    /// Aviso junto a «Preparar plan» mientras no haya permiso de IA.
    private var aiNotice: String? {
        if consentManager.hasConsent { return nil }
        return consentDeclined
            ? String(localized: "Crear un Kit requiere enviar tu objetivo al servicio de IA. Puedes dar el permiso cuando quieras.")
            : String(localized: "El plan lo prepara un servicio de IA externo. Te pedirá permiso antes de enviar nada.")
    }

    /// Resultado ya escrito (cuando el asistente propone otro Kit).
    var initialGoal: String?

    /// Abrir directamente la creación a mano (menú del «+» en Mis Kits).
    private let startsManual: Bool
    @State private var manual: Bool
    @Query private var allKits: [GoalEntity]

    // MARK: - ViewModel
    
    @State private var vm: KitCreatorViewModel?

    // MARK: - View State
    
    @FocusState private var focusedField: KitCreatorField?
    @State private var showAIConsent = false
    
    // MARK: - Initialization
    
    init(onKitCreated: ((Goal) -> Void)? = nil, initialDate: Date? = nil, initialGoal: String? = nil, startsManual: Bool = false) {
        self.onKitCreated = onKitCreated
        self.initialDate = initialDate
        self.initialGoal = initialGoal
        self.startsManual = startsManual
        _manual = State(initialValue: startsManual)
    }

    /// Los Kits a mano cuentan para el límite del plan gratis: la app lo comprueba antes de abrir la pantalla.
    private var reachesFreeLimit: Bool {
        guard let user = authManager.currentUser else { return false }
        return ManualKit.reachesFreeLimit(kits: allKits, ownerID: user.id, isPremium: user.isPremium)
    }

    /// Sin nada escrito, la pantalla de crear a mano. Con el formulario rellenado, el Kit se crea ya, sin
    /// pasar por otra pantalla, y los pasos se añaden en el propio Kit.
    private func startFromScratch(vm: KitCreatorViewModel) {
        if reachesFreeLimit {
            vm.planLimit = .activeKits
        } else if vm.hasDraft {
            createEmptyKit(vm: vm)
        } else {
            withAnimation(.smooth) { manual = true }
        }
    }

    private func createEmptyKit(vm: KitCreatorViewModel) {
        guard vm.isFormValid, let dueDate = vm.dueDate, let ownerID = authManager.currentUser?.id else { return }
        let kit = ManualKit.createEmpty(name: vm.description, dueDate: dueDate, doneWhen: vm.doneWhen,
                                        obstacles: vm.inconveniences, startingPoint: vm.startingPoint,
                                        stepMinutes: vm.sessionMinutes, ownerID: ownerID, context: modelContext)
        finishCreating(kit.toGoal())
    }

    var body: some View {
        NavigationStack {
            if manual {
                ManualKitCreatorView(initialName: vm?.description ?? initialGoal ?? "",
                                     initialDueDate: vm?.dueDate ?? initialDate,
                                     onCreated: finishCreating) {
                    if startsManual { dismiss() } else { withAnimation(.smooth) { manual = false } }
                }
            } else if let vm {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                let model = KitCreatorViewModel(apiClient: apiClient, initialDate: initialDate, initialGoal: initialGoal)
                vm = model
                if startsManual, reachesFreeLimit {
                    manual = false
                    model.planLimit = .activeKits
                }
            }
        }
    }
    
    @ViewBuilder
    private func content(vm: KitCreatorViewModel) -> some View {
        @Bindable var vm = vm
        Group {
            switch vm.viewState {
            case .form:
                KitCreationFormContent(
                    description: $vm.description,
                    dueDate: $vm.dueDate,
                    inconveniences: $vm.inconveniences,
                    doneWhen: $vm.doneWhen,
                    startingPoint: $vm.startingPoint,
                    sessionsPerWeek: $vm.sessionsPerWeek,
                    sessionMinutes: $vm.sessionMinutes,
                    oneSitting: $vm.oneSitting,
                    focusedField: $focusedField,
                    todayStart: vm.todayStart,
                    isDateInPast: vm.isDateInPast,
                    isFormValid: vm.isFormValid,
                    aiNotice: aiNotice,
                    onCreate: {
                        // Verificar consentimiento de IA antes de crear
                        guard consentManager.hasConsent else {
                            showAIConsent = true
                            return
                        }
                        
                        if let token = authManager.token {
                            vm.createKit(token: token)
                        } else {
                            vm.errorMessage = String(localized: "Necesitas iniciar sesión para crear un kit")
                            vm.showingError = true
                        }
                    },
                    onStartFromScratch: { startFromScratch(vm: vm) },
                    startFromScratchTitle: vm.hasDraft ? "Crear los pasos yo" : "Empezar de cero",
                    canStartFromScratch: !vm.hasDraft || vm.isFormValid
                )
            case .loading, .streaming:
                // Una sola pantalla de preparación: arranca en «Preparando» y sigue con los pasos.
                KitCreationStreamingProgress(
                    streamingState: $vm.streamingState,
                    onSave: { saveAndNavigate(vm: vm) },
                    onDiscard: { cancelAndDismiss(vm: vm) },
                    onAnswer: { vm.answerQuestions($0) },
                    onSkipQuestions: { vm.skipQuestions() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Sin «Listo» sobre el teclado: la tecla de retorno ya cierra, igual que tocar fuera o deslizar,
        // y al volver a abrir el creador la cápsula aparecía a veces suelta sobre el formulario.
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(vm.toolbarTitle)
                    .font(.headline)
            }

            ToolbarItem(placement: .cancellationAction) {
                if vm.showsCancelButton {
                    Button(vm.cancelButtonTitle) {
                        if vm.viewState == .form && vm.hasDraft {
                            confirmingDiscard = true
                        } else {
                            cancelAndDismiss(vm: vm)
                        }
                    }
                    .confirmationDialog("¿Descartar este Kit?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                        Button("Descartar", role: .destructive) { cancelAndDismiss(vm: vm) }
                        Button("Seguir editando", role: .cancel) { }
                    } message: {
                        Text("Se perderá lo que has escrito.")
                    }
                }
            }
        }
        // Una sola hoja para el formulario: dos .sheet en la misma jerarquía no conviven.
        .sheet(item: Binding(
            get: {
                if vm.showingDateSheet { return CreatorSheet.date }
                if showAIConsent { return CreatorSheet.aiConsent }
                return vm.planLimit.map { CreatorSheet.subscription($0) }
            },
            set: { if $0 == nil { vm.showingDateSheet = false; showAIConsent = false; vm.planLimit = nil } }
        )) { sheet in
            switch sheet {
            case .date:
                DateSelectionSheet(selectedDate: Binding(get: { vm.dueDate ?? vm.todayStart }, set: { vm.dueDate = $0 }),
                                   todayStart: vm.todayStart)
                    .presentationDetents(Set([.fraction(0.7), .large]), selection: $vm.sheetDetent)
                    .presentationDragIndicator(.visible)
            case .aiConsent:
                AIConsentView { granted in
                    showAIConsent = false
                    consentDeclined = !granted
                    // Con permiso, se sigue con lo que el usuario había pedido: crear el plan.
                    if granted, let token = authManager.token {
                        vm.createKit(token: token)
                    }
                }
                .interactiveDismissDisabled()
            case .subscription(let reason):
                NavigationStack {
                    SubscriptionView(reason: reason)
                }
            }
        }
        .alert("Error", isPresented: $vm.showingError) {
            Button("Reintentar") {
                if let token = authManager.token {
                    vm.createKit(token: token)
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? String(localized: "Ha ocurrido un error inesperado"))
        }
        .interactiveDismissDisabled(vm.viewState != .form)

        .onAppear {
             // Dependencies are injected via .task
        }
    }

    // MARK: - Actions

    private func cancelAndDismiss(vm: KitCreatorViewModel) {
        guard let ownerID = authManager.currentUser?.id else { return }
        // Desde el formulario se cierra; desde la preparación o «Tu plan» se vuelve
        // al formulario con lo escrito (cancelGeneration ya pone el estado en .form).
        let wasEditing = vm.viewState == .form
        vm.cancelGeneration(modelContext: modelContext, ownerID: ownerID)
        // El plan descartado ya estaba guardado en el servidor: se sincroniza enseguida para que
        // deje de contar como Kit activo.
        syncManager?.handleDataChange()
        if wasEditing {
            dismiss()
        }
    }

    private func saveAndNavigate(vm: KitCreatorViewModel) {
        guard let ownerID = authManager.currentUser?.id else { return }
        if let goal = vm.saveKit(in: modelContext, ownerID: ownerID) {
            finishCreating(goal)
        }
    }

    private func finishCreating(_ goal: Goal) {
        // Trigger sync
        syncManager?.handleDataChange()
        let goalID = goal.id
        let context = modelContext
        Task {
            // Primer momento en que un recordatorio tiene sentido: hay pasos con fecha.
            await NotificationService.shared.requestAuthorizationIfNeeded()
            let descriptor = FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == goalID })
            if let entity = try? context.fetch(descriptor).first {
                await NotificationService.shared.scheduleNotifications(for: entity)
            }
        }

        onKitCreated?(goal)
        dismiss()
    }
}

#if DEBUG
#Preview {
    KitCreatorView()
        .environment(AuthManager())
        .environment(AIConsentManager())
        .environment(\.apiClient, MockAPIClient())
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}
#endif

private enum CreatorSheet: Identifiable {
    case date, aiConsent
    case subscription(PlanLimitReason)
    var id: String {
        switch self {
        case .date: "date"
        case .aiConsent: "aiConsent"
        case .subscription(let reason): "subscription.\(reason.rawValue)"
        }
    }
}

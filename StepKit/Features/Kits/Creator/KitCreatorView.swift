//
//  KitCreatorView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import TipKit
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
    @Environment(\.storeKitManager) private var storeKitManager
    /// Con Pro en el iPhone y una cuenta que no lo refleja, se verifica antes de enseñar la pantalla de Pro.
    @State private var reconcilingSubscription = false
    @State private var limitFromManual = false

    // Callback cuando se crea un kit exitosamente
    var onKitCreated: ((Goal) -> Void)?

    // Fecha inicial opcional (para cuando se abre desde el calendario)
    var initialDate: Date?
    @State private var confirmingDiscard = false
    /// Resultado ya escrito (cuando el asistente propone otro Kit).
    var initialGoal: String?

    /// «Con IA» o «A mano»: se elige en la barra y se puede cambiar en cualquier momento sin perder lo escrito.
    @State private var manual = false
    /// La IA no puede preparar el plan (sin permiso, o falló): se ofrece seguir a mano.
    @State private var offersManualAfterConsent = false
    @Query private var allKits: [GoalEntity]

    // MARK: - ViewModel
    
    @State private var vm: KitCreatorViewModel?

    // MARK: - View State
    
    @FocusState private var focusedField: KitCreatorField?
    @State private var showAIConsent = false
    
    // MARK: - Initialization
    
    init(onKitCreated: ((Goal) -> Void)? = nil, initialDate: Date? = nil, initialGoal: String? = nil) {
        self.onKitCreated = onKitCreated
        self.initialDate = initialDate
        self.initialGoal = initialGoal
    }

    /// Los Kits a mano cuentan para el límite del plan gratis: la app lo comprueba antes de abrir la pantalla.
    private var reachesFreeLimit: Bool {
        guard let user = authManager.currentUser else { return false }
        return ManualKit.reachesFreeLimit(kits: allKits, ownerID: user.id, isPremium: user.isPremium)
    }

    /// Crea el Kit a mano con lo escrito en el formulario; los pasos se añaden en el propio Kit.
    private func createByHand(vm: KitCreatorViewModel) {
        if reachesFreeLimit {
            limitFromManual = true
            vm.planLimit = .activeKits
        } else {
            createEmptyKit(vm: vm)
        }
    }

    /// Cuando la IA no va a ayudar: pasa a «A mano» conservando el borrador y, si ya está completo, crea el Kit.
    private func continueByHand(vm: KitCreatorViewModel) {
        withAnimation(.formReveal) { manual = true }
        if vm.isFormValid { createByHand(vm: vm) }
    }

    private func createEmptyKit(vm: KitCreatorViewModel) {
        guard vm.isFormValid, let dueDate = vm.dueDate, let ownerID = authManager.currentUser?.id else { return }
        let kit = ManualKit.createEmpty(name: vm.description, dueDate: dueDate, doneWhen: vm.doneWhen,
                                        obstacles: vm.inconveniences, startingPoint: vm.startingPoint,
                                        stepMinutes: vm.sessionMinutes, ownerID: ownerID, context: modelContext)
        finishCreating(kit.toGoal(), asksForNotifications: false)
    }

    var body: some View {
        NavigationStack {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .onChange(of: vm?.planLimit) { _, limit in
            guard let vm, limit != nil, !reconcilingSubscription, storeKitManager.hasActiveSubscription,
                  authManager.currentUser?.isPremium != true else { return }
            reconcilingSubscription = true
            Task {
                let sync = await SubscriptionViewModel().reconcileEntitlement(storeKitManager: storeKitManager,
                                                                              apiClient: apiClient, authManager: authManager)
                if sync == .pro {
                    vm.planLimit = nil
                    if limitFromManual {
                        createByHand(vm: vm)
                    } else if let token = authManager.token, consentManager.hasConsent, vm.isFormValid {
                        vm.createKit(token: token)
                    }
                }
                reconcilingSubscription = false
            }
        }
        .task {
            if vm == nil {
                let model = KitCreatorViewModel(apiClient: apiClient, initialDate: initialDate, initialGoal: initialGoal)
                vm = model
                await storeKitManager.updatePurchasedProducts()
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
                    onCreate: {
                        if manual {
                            createByHand(vm: vm)
                            return
                        }
                        // Verificar consentimiento de IA antes de crear
                        guard consentManager.hasConsent else {
                            showAIConsent = true
                            return
                        }
                        
                        if let token = authManager.token {
                            limitFromManual = false
                            vm.createKit(token: token)
                        } else {
                            vm.errorMessage = String(localized: "Necesitas iniciar sesión para crear un kit")
                            vm.showingError = true
                        }
                    },
                    manual: manual
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

            // El modo se elige en la barra, donde iOS pone lo que afecta a toda la pantalla.
            if vm.viewState == .form {
                ToolbarItem(placement: .topBarTrailing) {
                    KitCreationModePicker(manual: Binding(get: { manual }, set: { value in
                        focusedField = nil
                        if value { StartFromScratchTip().invalidate(reason: .actionPerformed) }
                        withAnimation(.formReveal) { manual = value }
                    }))
                }
                // El selector ya es una cápsula: con el fondo de cristal de la barra se veían dos, una dentro de otra.
                .sharedBackgroundVisibility(.hidden)
            }
        }
        // Una sola hoja para el formulario: dos .sheet en la misma jerarquía no conviven.
        .sheet(item: Binding(
            get: {
                if vm.showingDateSheet { return CreatorSheet.date }
                if showAIConsent { return CreatorSheet.aiConsent }
                if reconcilingSubscription { return nil }
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
                    // Con permiso, se sigue con lo que el usuario había pedido: crear el plan.
                    if granted, let token = authManager.token {
                        vm.createKit(token: token)
                    } else if !granted {
                        // Sin permiso la IA no prepara el plan, pero el Kit se puede crear igual.
                        offersManualAfterConsent = true
                    }
                }
                .interactiveDismissDisabled()
            case .subscription(let reason):
                NavigationStack {
                    SubscriptionView(reason: reason)
                }
            }
        }
        .alert("Puedes crear el Kit a mano", isPresented: $offersManualAfterConsent) {
            Button("Crear el Kit a mano") { continueByHand(vm: vm) }
            Button("Ahora no", role: .cancel) { }
        } message: {
            Text("Sin ese permiso la IA no puede proponer los pasos. Los añades tú.")
        }
        .alert("Error", isPresented: $vm.showingError) {
            Button("Reintentar") {
                if let token = authManager.token {
                    vm.createKit(token: token)
                }
            }
            // La IA falló o no hay conexión: el Kit se puede crear igual, con lo ya escrito.
            if !manual {
                Button("Crear el Kit a mano") { continueByHand(vm: vm) }
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

    /// Un Kit hecho a mano nace sin pasos: el permiso de avisos se pide al añadir el primero.
    private func finishCreating(_ goal: Goal, asksForNotifications: Bool = true) {
        // Trigger sync
        syncManager?.handleDataChange()
        let goalID = goal.id
        let context = modelContext
        Task {
            // Primer momento en que un recordatorio tiene sentido: hay pasos con fecha.
            if asksForNotifications { await NotificationService.shared.requestAuthorizationIfNeeded() }
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

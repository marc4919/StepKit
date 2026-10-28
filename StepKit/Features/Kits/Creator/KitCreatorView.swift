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

    // MARK: - ViewModel
    
    @State private var vm: KitCreatorViewModel?

    // MARK: - View State
    
    @FocusState private var focusedField: KitCreatorField?
    @State private var showAIConsent = false
    /// Kit recién guardado al que se le reserva la primera sesión antes de cerrar.
    @State private var bookingKit: GoalEntity?
    @State private var createdGoal: Goal?
    
    // MARK: - Initialization
    
    init(onKitCreated: ((Goal) -> Void)? = nil, initialDate: Date? = nil) {
        self.onKitCreated = onKitCreated
        self.initialDate = initialDate
    }

    var body: some View {
        NavigationStack {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if vm == nil {
                vm = KitCreatorViewModel(apiClient: apiClient, initialDate: initialDate)
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
                    }
                )
            case .loading, .streaming:
                // Una sola pantalla de preparación: arranca en «Preparando» y sigue con los pasos.
                KitCreationStreamingProgress(
                    streamingState: $vm.streamingState,
                    onSave: { saveAndNavigate(vm: vm) },
                    onSaveAndBook: { saveAndBook(vm: vm) },
                    onDiscard: { cancelAndDismiss(vm: vm) },
                    onAnswer: { vm.answerQuestions($0) },
                    onSkipQuestions: { vm.skipQuestions() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(vm.toolbarTitle)
                    .font(.headline)
            }

            ToolbarItem(placement: .cancellationAction) {
                if vm.showsCancelButton {
                    Button(vm.cancelButtonTitle) {
                        cancelAndDismiss(vm: vm)
                    }
                }
            }
        }
        // Una sola hoja para el formulario: dos .sheet en la misma jerarquía no conviven.
        .sheet(item: Binding(
            get: {
                if let bookingKit { return CreatorSheet.booking(bookingKit) }
                if vm.showingDateSheet { return CreatorSheet.date }
                if showAIConsent { return CreatorSheet.aiConsent }
                return vm.planLimit.map { CreatorSheet.subscription($0) }
            },
            set: { if $0 == nil { vm.showingDateSheet = false; showAIConsent = false; vm.planLimit = nil; bookingKit = nil } }
        ), onDismiss: finishBookingIfNeeded) { sheet in
            switch sheet {
            case .booking(let kit):
                // Con la hora reservada, el aviso llega 10 minutos antes; al cerrar se va al Kit.
                BookSessionSheet(kits: [kit], initialKit: kit,
                                 initialStep: kit.orderedActiveSteps.first { !$0.isCompleted },
                                 initialDate: kit.orderedActiveSteps.first { !$0.isCompleted }?.suggestedDeadline ?? .now)
            case .date:
                DateSelectionSheet(selectedDate: $vm.dueDate, todayStart: vm.todayStart)
                    .presentationDetents(Set([.fraction(0.7), .large]), selection: $vm.sheetDetent)
                    .presentationDragIndicator(.visible)
            case .aiConsent:
                AIConsentView { granted in
                    showAIConsent = false
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

    /// Guarda el Kit y abre la reserva de su primera sesión; el creador se cierra después.
    private func saveAndBook(vm: KitCreatorViewModel) {
        guard let ownerID = authManager.currentUser?.id,
              let goal = vm.saveKit(in: modelContext, ownerID: ownerID) else { return }
        syncManager?.handleDataChange()
        createdGoal = goal
        let goalID = goal.id
        bookingKit = try? modelContext.fetch(FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == goalID })).first
        Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
        if bookingKit == nil { finishBookingIfNeeded() }
    }

    private func finishBookingIfNeeded() {
        guard let goal = createdGoal else { return }
        createdGoal = nil
        bookingKit = nil
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
    case booking(GoalEntity)
    var id: String {
        switch self {
        case .booking(let kit): "booking.\(kit.id)"
        case .date: "date"
        case .aiConsent: "aiConsent"
        case .subscription(let reason): "subscription.\(reason.rawValue)"
        }
    }
}

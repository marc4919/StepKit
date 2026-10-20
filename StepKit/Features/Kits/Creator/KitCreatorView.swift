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
                            vm.errorMessage = "Necesitas iniciar sesión para crear un kit"
                            vm.showingError = true
                        }
                    }
                )
            case .loading, .streaming:
                // Una sola pantalla de preparación: arranca en «Preparando» y sigue con los pasos.
                KitCreationStreamingProgress(
                    streamingState: $vm.streamingState,
                    onSave: { saveAndNavigate(vm: vm) },
                    onDiscard: { cancelAndDismiss(vm: vm) }
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
            get: { vm.showingDateSheet ? CreatorSheet.date : (showAIConsent ? CreatorSheet.aiConsent : nil) },
            set: { if $0 == nil { vm.showingDateSheet = false; showAIConsent = false } }
        )) { sheet in
            switch sheet {
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
            Text(vm.errorMessage ?? "Ha ocurrido un error inesperado")
        }
        .interactiveDismissDisabled(vm.viewState != .form)

        .onAppear {
             // Dependencies are injected via .task
        }
    }

    // MARK: - Actions

    private func cancelAndDismiss(vm: KitCreatorViewModel) {
        guard let ownerID = authManager.currentUser?.id else { return }
        vm.cancelGeneration(modelContext: modelContext, ownerID: ownerID)
        
        // Si estamos en form, cerrar. Si no, volver al form.
        if vm.viewState == .form {
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

private enum CreatorSheet: String, Identifiable {
    case date, aiConsent
    var id: String { rawValue }
}

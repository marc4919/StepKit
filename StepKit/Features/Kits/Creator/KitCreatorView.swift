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
    case description, obstacles, time
}

// MARK: - Main View

struct KitCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager

    // Callback cuando se crea un kit exitosamente
    var onKitCreated: ((Goal) -> Void)?

    // Fecha inicial opcional (para cuando se abre desde el calendario)
    var initialDate: Date?

    // MARK: - ViewModel
    
    @State private var vm: KitCreatorViewModel?

    // MARK: - View State
    
    @FocusState private var focusedField: KitCreatorField?
    
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
                    dailyAvailableTime: $vm.dailyAvailableTime,
                    showingDateSheet: $vm.showingDateSheet,
                    focusedField: $focusedField,
                    todayStart: vm.todayStart,
                    isDateInPast: vm.isDateInPast,
                    isFormValid: vm.isFormValid,
                    onCreate: {
                        if let token = authManager.token {
                            vm.createKit(token: token)
                        } else {
                            vm.errorMessage = "Necesitas iniciar sesión para crear un kit"
                            vm.showingError = true
                        }
                    }
                )
            case .loading:
                KitCreationLoadingView()
            case .streaming:
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
        .sheet(isPresented: $vm.showingDateSheet) {
            DateSelectionSheet(selectedDate: $vm.dueDate, todayStart: vm.todayStart)
                .presentationDetents(Set([.fraction(0.7), .large]), selection: $vm.sheetDetent)
                .presentationDragIndicator(.visible)
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
        vm.cancelGeneration(modelContext: modelContext)
        
        // Si estamos en form, cerrar. Si no, volver al form.
        if vm.viewState == .form {
            dismiss()
        }
    }

    private func saveAndNavigate(vm: KitCreatorViewModel) {
        if let goal = vm.saveKit(in: modelContext) {
            // Trigger sync
            syncManager?.handleDataChange()
            
            onKitCreated?(goal)
            dismiss()
        }
    }
}

#Preview {
    KitCreatorView()
        .environment(AuthManager())
        .environment(\.apiClient, MockAPIClient())
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}

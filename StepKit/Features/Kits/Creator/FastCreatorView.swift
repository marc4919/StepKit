//
//  FastCreatorView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared Types

// Moved to FastCreatorViewModel.swift or kept here if needed for FocusState
// Defining here to ensure availability if not strictly imported
enum FastCreatorField: Hashable {
    case description, obstacles, time
}

// MARK: - Main View

struct FastCreatorView: View {
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
    
    @State private var vm: FastCreatorViewModel

    // MARK: - View State
    
    @FocusState private var focusedField: FastCreatorField?
    
    // MARK: - Initialization
    
    init(onKitCreated: ((Goal) -> Void)? = nil, initialDate: Date? = nil) {
        self.onKitCreated = onKitCreated
        self.initialDate = initialDate
        // Initialize VM with a placeholder or defer initialization if we need environment
        // Since we need apiClient from Environment, we can't init VM here easily without custom init
        // But we can use a State(wrappedValue:) approach if we had access, but we don't have environment at init time.
        // So we'll use .onAppear or a separate init method.
        // However, standard pattern is to init State in init if possible, or use @StateObject (old).
        // With @Observable, we can use @State.
        // We will initialize it with a dummy and re-create in onAppear, or better:
        // Use a container view or simply force unwrap? No.
        // We will defer initialization to onAppear or use a constructor that doesn't need APIClient immediately?
        // No, VM needs APIClient.
        // Solution: Initialize in init using a "default" or make VM nullable?
        // Better: Pass dependencies to `FastCreatorView` init explicitly instead of Environment if possible?
        // No, standard SwiftUI.
        // We will use the pattern:
        // @State private var vm: FastCreatorViewModel?
        // And init in .task or .onAppear.
        _vm = State(initialValue: FastCreatorViewModel(apiClient: MockAPIClient(), initialDate: initialDate)) // Temporary placeholder
    }

    var body: some View {
        NavigationStack {
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
                        onSave: saveAndNavigate,
                        onDiscard: cancelAndDismiss
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
                            cancelAndDismiss()
                        }
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
            // Re-inject real dependencies
            // This is a bit of a hack for Environment injection into State, 
            // but common when migrating to pure MVVM without Dependency Injection container.
            // Ideally we would use a Factory or DI container.
            // For now, we update the VM with the real API client from environment.
            if vm.viewState == .form { // Only if not already running
                 // We can't easily swap the API client of an existing VM instance if it's let.
                 // We should probably create the VM here if it's the dummy.
                 // But strictly speaking, we can just init the VM with the Environment apiClient if we change the View init.
            }
        }
        .task {
            // Re-initialize VM with real dependencies if needed
            // Actually, best way is to make FastCreatorView not take dependencies from Environment for VM construction
            // but rather constructing the VM in the parent view.
            // But since we are refactoring only this file...
            // We will reconstruct the VM here.
            let newVM = FastCreatorViewModel(apiClient: apiClient, initialDate: initialDate)
            // Copy state if needed? No, it's fresh.
            self.vm = newVM
        }
    }

    // MARK: - Actions

    private func cancelAndDismiss() {
        vm.cancelGeneration(modelContext: modelContext)
        
        // Si estamos en form, cerrar. Si no, volver al form.
        if vm.viewState == .form {
            dismiss()
        }
    }

    private func saveAndNavigate() {
        if let goal = vm.saveKit(in: modelContext) {
            // Trigger sync
            syncManager?.handleDataChange()
            
            onKitCreated?(goal)
            dismiss()
        }
    }
}

#Preview {
    FastCreatorView()
        .environment(AuthManager())
        .environment(\.apiClient, MockAPIClient())
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}

//
//  TrainerView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit
import FoundationModels

struct TrainerView: View {
    // MARK: - SwiftData Query
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    /// Indica si el usuario tiene kits (real, basado en SwiftData)
    private var hasKits: Bool { !goalEntities.isEmpty }

    // MARK: - ViewModel
    @State private var viewModel = TrainerViewModel()

    // MARK: - View State
    @FocusState private var isInputFocused: Bool

    var body: some View {
        @Bindable var vm = viewModel
        
        Group {
            switch viewModel.modelAvailability {
            case .available:
                if hasKits {
                    AssistantConversationView(
                        messages: $vm.messages,
                        draft: $vm.draft,
                        showQuickActions: $vm.showQuickActions,
                        isTyping: $vm.isTyping,
                        isResponding: $vm.isResponding,
                        isInputFocused: $isInputFocused,
                        quickActions: viewModel.quickActions,
                        onSendMessage: { viewModel.sendDraft(goals: goalEntities) },
                        onQuickAction: { viewModel.sendQuickAction($0, goals: goalEntities) },
                        onResetConversation: { viewModel.showingResetAlert = true }
                    )
                } else {
                    NoKitsEmptyState(onCreateKit: { viewModel.showingKitCreator = true })
                }
            case .unavailable(.deviceNotEligible):
                ModelNotAvailableState(
                    title: "Dispositivo no compatible",
                    message: "Este dispositivo no es compatible con Apple Intelligence.",
                    showSettingsHint: false
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                ModelNotAvailableState(
                    title: "Apple Intelligence desactivado",
                    message: "Activa Apple Intelligence en Ajustes para usar el asistente.",
                    showSettingsHint: true
                )
            case .unavailable(.modelNotReady):
                ModelNotAvailableState(
                    title: "Modelo en preparación",
                    message: "El asistente se está descargando. Inténtalo de nuevo más tarde.",
                    showSettingsHint: false
                )
            case .unavailable:
                ModelNotAvailableState(
                    title: "Asistente no disponible",
                    message: "El asistente no está disponible en este momento.",
                    showSettingsHint: false
                )
            @unknown default:
                ModelNotAvailableState(
                    title: "Asistente no disponible",
                    message: "El asistente no está disponible.",
                    showSettingsHint: false
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Asistente")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $vm.showingKitCreator) {
            KitCreatorView()
        }
        .alert("Nueva conversación", isPresented: $vm.showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Reiniciar", role: .destructive) {
                viewModel.resetConversation(goals: goalEntities)
            }
        } message: {
            Text("¿Quieres empezar una nueva conversación? Se borrarán los mensajes actuales.")
        }
        .onAppear {
            viewModel.onAppear(goals: goalEntities)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        // Sincronizar foco si es necesario, aunque el VM no controla el foco directamente,
        // la vista reacciona a acciones del usuario.
        .onChange(of: viewModel.isResponding) { _, isResponding in
            if isResponding {
                isInputFocused = false
            }
        }
    }
}

#Preview("Con kits") {
    NavigationStack {
        TrainerView()
    }
}

#Preview("Sin kits") {
    NavigationStack {
        TrainerView()
    }
}

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
    @Environment(AuthManager.self) private var authManager
    // MARK: - SwiftData Query
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted }, sort: \GoalEntity.createdAt, order: .reverse)
    private var goalEntities: [GoalEntity]

    /// Indica si el usuario tiene kits (real, basado en SwiftData)
    private var visibleGoalEntities: [GoalEntity] {
        guard let ownerID = authManager.currentUser?.id else { return [] }
        return goalEntities.filter { $0.ownerID == ownerID }
    }

    private var hasKits: Bool { !visibleGoalEntities.isEmpty }

    // MARK: - ViewModel
    @State private var viewModel = TrainerViewModel()

    // MARK: - View State
    @FocusState private var isInputFocused: Bool
    @State private var selectedKitID: UUID?

    /// Kits en curso, el último que avanzaste primero.
    private var activeKits: [GoalEntity] {
        visibleGoalEntities.filter { !$0.isCompleted }.sorted { $0.lastActivity > $1.lastActivity }
    }

    private var selectedKit: GoalEntity? {
        activeKits.first { $0.id == selectedKitID } ?? activeKits.first
    }

    /// El asistente trabaja sobre el Kit elegido; sin Kits en curso, sobre todos.
    private var contextGoals: [GoalEntity] {
        selectedKit.map { [$0] } ?? visibleGoalEntities
    }

    var body: some View {
        @Bindable var vm = viewModel
        
        NavigationStack {
        Group {
            switch viewModel.modelAvailability {
            case .available:
                if hasKits {
                    AssistantHomeView(
                        messages: viewModel.messages,
                        draft: $vm.draft,
                        isTyping: viewModel.isTyping,
                        isResponding: viewModel.isResponding,
                        isInputFocused: $isInputFocused,
                        onSend: { viewModel.sendDraft(goals: contextGoals) },
                        onIntent: { intent in
                            viewModel.sendIntent(title: intent.title, prompt: intent.prompt(kit: selectedKit),
                                                 goals: contextGoals)
                        },
                        onRetry: { viewModel.retryLast(goals: contextGoals) }
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
        .toolbar {
            if hasKits, let kit = selectedKit {
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("Kit", selection: Binding(get: { kit.id }, set: { selectKit($0) })) {
                            ForEach(activeKits) { Text($0.title).tag($0.id) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(kit.title).font(.headline).lineLimit(1)
                            Image(systemName: "chevron.down").font(.caption.bold())
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Kit: \(kit.title). Cambiar")
                    .accessibilityIdentifier("assistant.kitPicker")
                }
            }
            if hasKits {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nueva conversación", systemImage: "square.and.pencil") {
                        viewModel.showingResetAlert = true
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $vm.showingKitCreator) {
            KitCreatorView()
        }
        .alert("Nueva conversación", isPresented: $vm.showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Reiniciar", role: .destructive) {
                viewModel.resetConversation(goals: contextGoals)
            }
        } message: {
            Text("Se borrarán los mensajes de esta conversación. Tu plan y tus registros se conservan.")
        }
        .onAppear {
            viewModel.onAppear(goals: visibleGoalEntities)
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

    /// Cambiar de Kit empieza una conversación nueva con ese contexto.
    private func selectKit(_ id: UUID) {
        guard id != selectedKit?.id else { return }
        selectedKitID = id
        if !viewModel.messages.isEmpty {
            viewModel.resetConversation(goals: contextGoals)
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

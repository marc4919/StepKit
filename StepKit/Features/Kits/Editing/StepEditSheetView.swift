//
//  StepEditSheetView.swift
//  StepKit
//

import SwiftData
import SwiftUI

struct StepEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager

    let stepEntity: StepEntity

    @State private var draft: StepEditDraft
    @State private var showingSaveError = false

    init(stepEntity: StepEntity) {
        self.stepEntity = stepEntity
        _draft = State(initialValue: StepEditDraft(step: stepEntity))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Paso") {
                    TextField("Título del paso", text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("stepEdit.title")

                    TextField("Descripción breve", text: $draft.shortDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("stepEdit.shortDescription")
                }

                Section {
                    TextEditor(text: $draft.longDescription)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Descripción detallada")
                        .accessibilityIdentifier("stepEdit.longDescription")
                } header: {
                    Text("Descripción detallada")
                } footer: {
                    Text("Describe la acción concreta necesaria para completar este paso.")
                }
            }
            .navigationTitle("Editar paso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .accessibilityIdentifier("stepEdit.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(!draft.isValid || !draft.hasChanges(comparedTo: stepEntity))
                    .accessibilityIdentifier("stepEdit.save")
                }
            }
            .alert("No se pudo guardar el paso", isPresented: $showingSaveError) {
                Button("Aceptar", role: .cancel) { }
            } message: {
                Text("Los cambios no se han confirmado. Inténtalo de nuevo.")
            }
        }
        .interactiveDismissDisabled(draft.hasChanges(comparedTo: stepEntity))
    }

    private func save() {
        guard let ownerID = authManager.currentUser?.id else {
            showingSaveError = true
            return
        }

        do {
            try modelContext.transaction {
                _ = try draft.apply(to: stepEntity, expectedOwnerID: ownerID)
            }
            syncManager?.handleDataChange()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let step = StepEntity(
        stepTitle: "Preparar material",
        descriptionShort: "Reúne lo necesario",
        descriptionLong: "Haz una lista y deja preparado todo el material antes de empezar.",
        estimateMinutes: 20
    )
    container.mainContext.insert(step)

    return StepEditSheetView(stepEntity: step)
        .modelContainer(container)
        .environment(AuthManager())
}

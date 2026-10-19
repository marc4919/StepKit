//
//  ProgressSheets.swift
//  StepKit
//
//  Hojas v4.4 «Guardar avance» y «Editar registro».
//

import SwiftUI
import SwiftData

struct SaveProgressSheet: View {
    let step: StepEntity
    let stepNumber: Int
    /// Abre directamente con «Estoy bloqueado» seleccionado.
    var startsBlocked = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var note = ""
    @State private var canContinue = true
    @State private var reason = ""
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        if let kit = step.goal {
                            ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount,
                                         size: 40, showsLabel: false)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(text: "\(step.goal?.title ?? "") · Paso \(stepNumber)")
                            Text(step.stepTitle).font(.headline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                Section {
                    TextField("Qué hiciste y qué falta", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("progress.note")
                } header: {
                    Text("Lo que has avanzado (opcional)")
                }
                Section {
                    Picker("¿Puedes seguir?", selection: $canContinue) {
                        Text("Puedo seguir").tag(true)
                        Text("Estoy bloqueado").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress.canContinue")
                    if !canContinue {
                        TextField("Qué te frena (opcional)", text: $reason, axis: .vertical)
                            .lineLimit(2...4)
                            .accessibilityIdentifier("progress.blockedReason")
                    }
                } header: {
                    Text("¿Puedes seguir con este paso?")
                } footer: {
                    Text(canContinue
                         ? "Tu avance se guarda y el paso seguirá en curso."
                         : "Tu avance se guarda igualmente. El paso quedará bloqueado hasta que lo resuelvas.")
                }
            }
            .navigationTitle("Guardar avance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .accessibilityIdentifier("progress.save")
                }
            }
            .alert("No se pudo guardar el avance", isPresented: $saveFailed) {
                Button("Aceptar", role: .cancel) {}
            }
        }
        .onAppear {
            canContinue = !(startsBlocked || step.isBlocked)
            reason = step.blockedReason ?? ""
        }
        .animation(.default, value: canContinue)
    }

    private func save() {
        do {
            let blocked = canContinue ? nil : (reason.isEmpty ? "Sin detallar" : reason)
            try ProgressLog.saveProgress(for: step, note: note, blockedReason: blocked, context: modelContext)
            syncManager?.handleDataChange()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

struct EditProgressEntrySheet: View {
    let entry: ProgressEntryEntity
    let stepLabel: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var note = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let stepLabel {
                        LabeledContent("Paso", value: stepLabel)
                    }
                    LabeledContent("Fecha", value: entry.notedAt.formatted(date: .abbreviated, time: .omitted))
                }
                Section {
                    TextField("Nota", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Nota")
                } footer: {
                    Text("Editar la nota conserva su fecha y no cambia el estado del paso.")
                }
                Section {
                    Button("Eliminar registro", role: .destructive) { confirmingDelete = true }
                }
            }
            .navigationTitle("Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        try? ProgressLog.edit(entry, note: note, context: modelContext)
                        syncManager?.handleDataChange()
                        dismiss()
                    }
                    .disabled(note == entry.note)
                }
            }
            .confirmationDialog("¿Eliminar este registro?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar registro", role: .destructive) {
                    try? ProgressLog.delete(entry, context: modelContext)
                    syncManager?.handleDataChange()
                    dismiss()
                }
            } message: {
                Text("El estado del paso no cambia.")
            }
        }
        .onAppear { note = entry.note }
    }
}

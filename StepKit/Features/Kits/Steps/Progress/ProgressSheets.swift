//
//  ProgressSheets.swift
//  StepKit
//
//  Hojas v4.4 «Guardar avance» y «Editar registro».
//

import SwiftUI
import TipKit
import SwiftData

struct SaveProgressSheet: View {
    let step: StepEntity
    let stepNumber: Int
    /// «Atasco»: la hoja pide qué te frena. Si no, es «Avance»: solo lo que has hecho.
    var startsBlocked = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(AuthManager.self) private var authManager
    @State private var note = ""
    @State private var reason = ""
    @State private var saveFailed = false
    @FocusState private var focused: Field?

    private enum Field { case note, reason }
    private var reportingBlock: Bool { startsBlocked }

    var body: some View {
        // Barra propia, fija: en el Duo cerrado, con el teclado abierto, el sistema escondía la
        // barra de navegación al desplazar y «Guardar» desaparecía. Mismo aspecto, pero no se mueve.
        VStack(spacing: 0) {
            SheetBar(title: reportingBlock ? String(localized: "Me he atascado") : String(localized: "Guardar avance"),
                     canSave: canSave, onCancel: { dismiss() }, onSave: { save() })
            Form {
                Section {
                    HStack(spacing: 12) {
                        if let kit = step.goal {
                            ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount,
                                         size: 40, showsLabel: false)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(text: String(localized: "\(step.goal?.title ?? "") · Paso \(stepNumber)"))
                            Text(step.stepTitle).font(.headline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if reportingBlock {
                    Section {
                        TextField("Ej.: «Me falta el permiso del cliente»", text: $reason, axis: .vertical)
                            .lineLimit(2...5)
                            .focused($focused, equals: .reason)
                            .accessibilityIdentifier("progress.blockedReason")
                    } header: {
                        Text("¿Qué te frena?")
                    } footer: {
                        Text("El paso queda bloqueado hasta que lo resuelvas. El asistente puede proponerte cómo seguir.")
                    }
                    Section {
                        TextField("Ej.: «Escribí la introducción»", text: $note, axis: .vertical)
                            .lineLimit(2...6)
                            .focused($focused, equals: .note)
                            .accessibilityIdentifier("progress.note")
                    } header: {
                        Text("Lo que llevas hecho (opcional)")
                    }
                } else {
                    Section {
                        TextField("Ej.: «Escribí la introducción. Me falta el resultado»", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($focused, equals: .note)
                            .accessibilityIdentifier("progress.note")
                    } header: {
                        Text("¿Qué has hecho hoy?")
                    } footer: {
                        Text("Apúntalo para retomarlo sin pensar la próxima vez. Se guarda con la fecha y la hora, y no completa el paso.")
                    }
                }
            }
            .alert("No se pudo guardar el avance", isPresented: $saveFailed) {
                Button("Aceptar", role: .cancel) {}
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if reportingBlock { reason = step.blockedReason ?? "" }
            focused = reportingBlock ? .reason : .note
        }
    }

    private var canSave: Bool {
        reportingBlock ? !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                       : !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            // Avance no cambia el estado del paso: si ya estaba bloqueado, sigue bloqueado.
            try ProgressLog.saveProgress(for: step, note: note,
                                         blockedReason: reportingBlock ? reason.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                         context: modelContext, keepsBlockState: !reportingBlock)
            TipFlow.firstProgressSaved = true
            syncManager?.handleDataChange()
            // El asistente reacciona: con un bloqueo puede proponer cómo seguir.
            if let kit = step.goal {
                KitAssistant.react(reportingBlock ? .blocked : .progress, kit: kit, step: step,
                                   context: modelContext, apiClient: apiClient, token: authManager.token)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

struct EditProgressEntrySheet: View {
    let entry: ProgressEntryEntity
    /// Paso al que pertenece la nota: número y título.
    let step: (number: Int, title: String)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var note = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let step {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paso \(step.number)")
                            Text(step.title).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
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

/// Nueva nota general del Kit. Aparece en el Registro y se sincroniza.
struct KitNoteSheet: View {
    let kit: GoalEntity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var note = ""
    @FocusState private var focused: Bool

    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Escribe una nota…", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                        .accessibilityIdentifier("kitNote.text")
                } footer: {
                    Text("Para apuntes que no son de un paso concreto. La verás en el Registro del Kit.")
                }
            }
            .navigationTitle("Nota del Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        try? ProgressLog.addKitNote(trimmed, kit: kit, context: modelContext)
                        syncManager?.handleDataChange()
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                    .accessibilityIdentifier("kitNote.save")
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Barra de una hoja de edición que no se esconde nunca: Cancelar, título y la acción principal,
/// con el aspecto de la barra del sistema.
struct SheetBar: View {
    let title: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancelar", action: onCancel)
                    .buttonStyle(.glass)
                Spacer()
                Button("Guardar", action: onSave)
                    .buttonStyle(.glass)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("progress.save")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

//
//  StepProgress.swift
//  StepKit
//
//  Estado de un paso en v4.4 y operaciones del registro de avance.
//

import SwiftUI
import SwiftData

/// Estados de paso con símbolo y texto propios. El color nunca va solo.
enum StepProgressState {
    case pending, inProgress, blocked, done

    var symbol: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "hand.raised.circle.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: .secondary
        case .inProgress: .accentColor
        case .blocked: .red
        case .done: .green
        }
    }

    var label: String {
        switch self {
        case .pending: "Pendiente"
        case .inProgress: "En curso"
        case .blocked: "Bloqueado"
        case .done: "Completado"
        }
    }
}

extension StepEntity {
    var isBlocked: Bool { blockedReason != nil }

    /// `entries` son las entradas visibles de este paso (sin borrar).
    func progressState(hasEntries: Bool) -> StepProgressState {
        if isCompleted { return .done }
        if isBlocked { return .blocked }
        return hasEntries ? .inProgress : .pending
    }
}

extension Sequence where Element == ProgressEntryEntity {
    /// Entradas visibles, de la más reciente a la más antigua.
    var visibleNewestFirst: [ProgressEntryEntity] {
        filter { $0.deletedAt == nil }.sorted { $0.notedAt > $1.notedAt }
    }
}

/// Operaciones sobre el registro de avance. Cada una deja los relojes LWW listos para sync.
@MainActor
enum ProgressLog {
    /// Guarda un avance parcial. Si `blockedReason` no es nil, el paso queda bloqueado.
    static func saveProgress(
        for step: StepEntity,
        note: String,
        blockedReason: String?,
        context: ModelContext,
        now: Date = Date()
    ) throws {
        guard let kit = step.goal else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = blockedReason?.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty || reason == nil {
            context.insert(ProgressEntryEntity(
                ownerID: step.ownerID, kitID: kit.id, stepID: step.id, kind: .progress,
                note: trimmed, notedAt: now, createdAt: now, updatedAt: now
            ))
        }
        if let reason {
            context.insert(ProgressEntryEntity(
                ownerID: step.ownerID, kitID: kit.id, stepID: step.id, kind: .blocked,
                note: reason, notedAt: now.addingTimeInterval(0.001), createdAt: now, updatedAt: now
            ))
            step.blockedReason = reason
            step.blockedAt = now
        } else if step.isBlocked {
            step.blockedReason = nil
            step.blockedAt = nil
        }
        step.markModified(at: now)
        try context.save()
    }

    /// Nota general del Kit: un registro sin paso, que se sincroniza como el resto del registro.
    static func addKitNote(_ note: String, kit: GoalEntity, context: ModelContext, now: Date = Date()) throws {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(ProgressEntryEntity(
            ownerID: kit.ownerID, kitID: kit.id, stepID: nil, kind: .progress,
            note: trimmed, notedAt: now, createdAt: now, updatedAt: now
        ))
        kit.markModified(at: now)
        try context.save()
    }

    /// Las notas del Kit vivían solo en este iPhone (UserDefaults): pasan al registro para sincronizarse.
    static func importLegacyKitNotes(for kit: GoalEntity, context: ModelContext, now: Date = Date()) {
        let key = "kit_annotations_\(kit.id)"
        guard let saved = UserDefaults.standard.stringArray(forKey: key), !saved.isEmpty else { return }
        // Se guardaban de la más reciente a la más antigua; se conserva ese orden.
        for (offset, note) in saved.enumerated() {
            let date = now.addingTimeInterval(-Double(offset))
            context.insert(ProgressEntryEntity(
                ownerID: kit.ownerID, kitID: kit.id, stepID: nil, kind: .progress,
                note: note, notedAt: date, createdAt: date, updatedAt: now
            ))
        }
        kit.markModified(at: now)
        if (try? context.save()) != nil {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Marca el paso como hecho o pendiente y actualiza el progreso del Kit.
    static func toggleCompletion(of step: StepEntity, context: ModelContext) throws {
        step.isCompleted.toggle()
        step.markModified()
        if let kit = step.goal {
            kit.progress = kit.computedProgress
            kit.markModified()
        }
        try context.save()
    }

    /// Quita el bloqueo; el avance guardado se conserva.
    static func resolveBlock(for step: StepEntity, context: ModelContext, now: Date = Date()) throws {
        guard step.isBlocked else { return }
        step.blockedReason = nil
        step.blockedAt = nil
        step.markModified(at: now)
        try context.save()
    }

    /// Editar la nota conserva su fecha y no cambia el estado del paso.
    static func edit(_ entry: ProgressEntryEntity, note: String, context: ModelContext, now: Date = Date()) throws {
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.markModified(at: now)
        try context.save()
    }

    static func delete(_ entry: ProgressEntryEntity, context: ModelContext, now: Date = Date()) throws {
        entry.markAsDeleted(at: now)
        try context.save()
    }

    /// Confirmar o reabrir el resultado del Kit.
    static func setResultConfirmed(_ confirmed: Bool, kit: GoalEntity, context: ModelContext, now: Date = Date()) throws {
        kit.resultConfirmedAt = confirmed ? now : nil
        kit.markModified(at: now)
        try context.save()
    }
}

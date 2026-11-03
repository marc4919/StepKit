//
//  ContentEditing.swift
//  StepKit
//
//  Focused editing support for the existing Kit and Step content model.
//

import Foundation

enum ContentEditingError: Error, Equatable {
    case emptyKitTitle
    case emptyKitKPI
    case emptyStepTitle
    case ownerMismatch
    case deletedContent
    case staleContent
    case missingParentKit
}

struct KitEditDraft: Equatable {
    var title: String
    var kpi: String
    /// Fecha final elegida; sin elegir, se queda la que tenga el Kit.
    var targetDate: Date?
    /// Un Kit creado a mano puede no tener indicador: no se exige para poder editarlo.
    private let kpiIsOptional: Bool
    private let baselineVersion: Int?
    private let baselineUpdatedAt: Date?

    init(title: String, kpi: String) {
        self.title = title
        self.kpi = kpi
        self.kpiIsOptional = false
        self.baselineVersion = nil
        self.baselineUpdatedAt = nil
    }

    init(kit: GoalEntity) {
        self.title = kit.planTitle
        self.kpi = kit.kpi
        self.targetDate = kit.targetDate
        self.kpiIsOptional = kit.kpi.trimmedForEditing.isEmpty
        self.baselineVersion = kit.version
        self.baselineUpdatedAt = kit.updatedAt
    }

    var isValid: Bool {
        !normalizedTitle.isEmpty && (kpiIsOptional || !normalizedKPI.isEmpty)
    }

    func hasChanges(comparedTo kit: GoalEntity) -> Bool {
        normalizedTitle != kit.planTitle || normalizedKPI != kit.kpi || changesTargetDate(of: kit)
    }

    func changesTargetDate(of kit: GoalEntity) -> Bool {
        guard let targetDate else { return false }
        guard let current = kit.targetDate else { return true }
        return !Calendar.current.isDate(targetDate, inSameDayAs: current)
    }

    @discardableResult
    func apply(
        to kit: GoalEntity,
        expectedOwnerID: String,
        at date: Date = Date()
    ) throws -> Bool {
        guard !normalizedTitle.isEmpty else {
            throw ContentEditingError.emptyKitTitle
        }
        guard kpiIsOptional || !normalizedKPI.isEmpty else {
            throw ContentEditingError.emptyKitKPI
        }
        guard !expectedOwnerID.isEmpty, kit.ownerID == expectedOwnerID else {
            throw ContentEditingError.ownerMismatch
        }
        guard !kit.isRemoved else {
            throw ContentEditingError.deletedContent
        }
        if let baselineVersion, let baselineUpdatedAt {
            guard kit.version == baselineVersion, kit.updatedAt == baselineUpdatedAt else {
                throw ContentEditingError.staleContent
            }
        }
        guard hasChanges(comparedTo: kit) else { return false }

        kit.planTitle = normalizedTitle
        kit.kpi = normalizedKPI
        if changesTargetDate(of: kit), let targetDate {
            let calendar = Calendar.current
            let due = calendar.startOfDay(for: targetDate)
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: kit.createdAt), to: due).day ?? 0
            kit.targetDate = due
            kit.horizonDays = max(days + 1, 1)
        }
        kit.markModified(at: date)
        return true
    }

    private var normalizedTitle: String { title.trimmedForEditing }
    private var normalizedKPI: String { kpi.trimmedForEditing }
}

struct StepEditDraft: Equatable {
    var title: String
    var shortDescription: String
    var longDescription: String
    /// Fecha y minutos del paso; nil si no se editan.
    var deadline: Date?
    var estimateMinutes: Int?
    private let baselineUpdatedAt: Date?

    init(title: String, shortDescription: String, longDescription: String,
         deadline: Date? = nil, estimateMinutes: Int? = nil) {
        self.title = title
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.deadline = deadline
        self.estimateMinutes = estimateMinutes
        self.baselineUpdatedAt = nil
    }

    init(step: StepEntity) {
        self.title = step.stepTitle
        self.shortDescription = step.descriptionShort
        self.longDescription = step.descriptionLong
        self.deadline = step.suggestedDeadline
        self.estimateMinutes = step.estimateMinutes
        self.baselineUpdatedAt = step.updatedAt
    }

    /// Cambia la fecha (día distinto) respecto al paso guardado.
    func changesDate(of step: StepEntity) -> Bool {
        guard let deadline else { return false }
        guard let current = step.suggestedDeadline else { return true }
        return !Calendar.current.isDate(deadline, inSameDayAs: current)
    }

    var isValid: Bool {
        !normalizedTitle.isEmpty
    }

    func hasChanges(comparedTo step: StepEntity) -> Bool {
        normalizedTitle != step.stepTitle
            || normalizedShortDescription != step.descriptionShort
            || normalizedLongDescription != step.descriptionLong
            || changesDate(of: step)
            || (estimateMinutes.map { $0 != step.estimateMinutes } ?? false)
    }

    @discardableResult
    func apply(
        to step: StepEntity,
        expectedOwnerID: String,
        at date: Date = Date()
    ) throws -> Bool {
        guard !normalizedTitle.isEmpty else {
            throw ContentEditingError.emptyStepTitle
        }
        guard !expectedOwnerID.isEmpty, step.ownerID == expectedOwnerID else {
            throw ContentEditingError.ownerMismatch
        }
        guard step.deletedAt == nil else {
            throw ContentEditingError.deletedContent
        }
        guard let parentKit = step.goal else {
            throw ContentEditingError.missingParentKit
        }
        guard parentKit.ownerID == expectedOwnerID else {
            throw ContentEditingError.ownerMismatch
        }
        guard !parentKit.isRemoved else {
            throw ContentEditingError.deletedContent
        }
        if let baselineUpdatedAt {
            guard step.updatedAt == baselineUpdatedAt else {
                throw ContentEditingError.staleContent
            }
        }
        guard hasChanges(comparedTo: step) else { return false }

        step.stepTitle = normalizedTitle
        step.descriptionShort = normalizedShortDescription
        step.descriptionLong = normalizedLongDescription
        if changesDate(of: step) { step.suggestedDeadline = deadline }
        if let estimateMinutes { step.estimateMinutes = estimateMinutes }
        step.markModified(at: date)
        return true
    }

    private var normalizedTitle: String { title.trimmedForEditing }
    private var normalizedShortDescription: String { shortDescription.trimmedForEditing }
    private var normalizedLongDescription: String { longDescription.trimmedForEditing }
}

private extension String {
    var trimmedForEditing: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

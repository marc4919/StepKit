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
    private let baselineVersion: Int?
    private let baselineUpdatedAt: Date?

    init(title: String, kpi: String) {
        self.title = title
        self.kpi = kpi
        self.baselineVersion = nil
        self.baselineUpdatedAt = nil
    }

    init(kit: GoalEntity) {
        self.title = kit.planTitle
        self.kpi = kit.kpi
        self.baselineVersion = kit.version
        self.baselineUpdatedAt = kit.updatedAt
    }

    var isValid: Bool {
        !normalizedTitle.isEmpty && !normalizedKPI.isEmpty
    }

    func hasChanges(comparedTo kit: GoalEntity) -> Bool {
        normalizedTitle != kit.planTitle || normalizedKPI != kit.kpi
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
        guard !normalizedKPI.isEmpty else {
            throw ContentEditingError.emptyKitKPI
        }
        guard !expectedOwnerID.isEmpty, kit.ownerID == expectedOwnerID else {
            throw ContentEditingError.ownerMismatch
        }
        guard !kit.isDeleted, kit.deletedAt == nil else {
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
    private let baselineUpdatedAt: Date?

    init(title: String, shortDescription: String, longDescription: String) {
        self.title = title
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.baselineUpdatedAt = nil
    }

    init(step: StepEntity) {
        self.title = step.stepTitle
        self.shortDescription = step.descriptionShort
        self.longDescription = step.descriptionLong
        self.baselineUpdatedAt = step.updatedAt
    }

    var isValid: Bool {
        !normalizedTitle.isEmpty
    }

    func hasChanges(comparedTo step: StepEntity) -> Bool {
        normalizedTitle != step.stepTitle
            || normalizedShortDescription != step.descriptionShort
            || normalizedLongDescription != step.descriptionLong
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
        guard !parentKit.isDeleted, parentKit.deletedAt == nil else {
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

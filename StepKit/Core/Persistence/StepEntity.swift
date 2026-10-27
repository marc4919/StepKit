//
//  StepEntity.swift
//  StepKit
//
//  Modelo SwiftData para persistencia local de Steps
//

import Foundation
import SwiftData

@Model
final class StepEntity {
    @Attribute(.unique) var id: UUID
    var ownerID: String = ""
    var stepTitle: String
    var descriptionShort: String
    var descriptionLong: String
    var estimateMinutes: Int
    var suggestedDeadline: Date?
    var effortLevel: String
    var adaptsTo: String
    var blockedByPremium: Bool
    var order: Int
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var notificationEnabled: Bool
    /// Motivo del bloqueo actual; `nil` si el paso no está bloqueado.
    var blockedReason: String?
    var blockedAt: Date?
    /// Momento en que se completó; `nil` si está pendiente o se completó antes de guardarlo.
    var completedAt: Date?
    /// Paso que se repite: "day" o "week", y cuántas sesiones. `nil` si es puntual.
    /// `suggestedDeadline` es la primera sesión y `estimateMinutes`, lo que dura cada una.
    var repeatEvery: String?
    var repeatTimes: Int?

    var goal: GoalEntity?
    
    init(
        id: UUID = UUID(),
        ownerID: String = "",
        stepTitle: String,
        descriptionShort: String,
        descriptionLong: String,
        estimateMinutes: Int,
        suggestedDeadline: Date? = nil,
        effortLevel: String = "medium",
        adaptsTo: String = "",
        blockedByPremium: Bool = false,
        order: Int = 0,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        notificationEnabled: Bool = true
    ) {
        self.id = id
        self.ownerID = ownerID
        self.stepTitle = stepTitle
        self.descriptionShort = descriptionShort
        self.descriptionLong = descriptionLong
        self.estimateMinutes = estimateMinutes
        self.suggestedDeadline = suggestedDeadline
        self.effortLevel = effortLevel
        self.adaptsTo = adaptsTo
        self.blockedByPremium = blockedByPremium
        self.order = order
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.notificationEnabled = notificationEnabled
    }

    // MARK: - Conversion from StepDTO
    
    convenience init(from dto: StepDTO, goal: GoalEntity) {
        self.init(
            id: dto.id ?? UUID(),
            ownerID: goal.ownerID,
            stepTitle: dto.title,
            descriptionShort: dto.descriptionShort,
            descriptionLong: dto.descriptionLong,
            estimateMinutes: dto.estimateMinutes,
            suggestedDeadline: dto.suggestedDeadline,
            effortLevel: dto.effortLevel,
            adaptsTo: dto.adaptsTo,
            blockedByPremium: dto.blockedByPremium,
            order: dto.order,
            isCompleted: dto.completed,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            deletedAt: dto.deletedAt
        )
        self.goal = goal
        self.repeatEvery = dto.repeatEvery
        self.repeatTimes = dto.repeatTimes
    }
    
    // MARK: - Conversion to Step (view model)
    
    func toStep() -> Step {
        Step(
            id: id,
            stepTitle: stepTitle,
            description: StepDescription(short: descriptionShort, long: descriptionLong),
            estimateMinutes: estimateMinutes,
            suggestedDeadline: suggestedDeadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            isCompleted: isCompleted,
            goalId: goal?.id
        )
    }
    
    // MARK: - Computed Properties

    var title: String { stepTitle }

    // MARK: - Modification Tracking

    /// Marca la entidad como modificada localmente (actualiza timestamp).
    /// Nunca retrocede el reloj LWW si el estado remoto observado estaba adelantado.
    func markModified(at date: Date = Date()) {
        updatedAt = max(date, updatedAt.addingTimeInterval(0.001))
        // También marca el goal parent como modificado
        goal?.markModified(at: updatedAt)
    }

    // MARK: - Sync Conversion

    /// Convierte la entidad a DTO para sincronización
    func toSyncDTO() -> StepSyncDTO {
        StepSyncDTO(
            id: id,
            kitId: goal?.id ?? UUID(),
            title: stepTitle,
            descriptionShort: descriptionShort,
            descriptionLong: descriptionLong,
            estimateMinutes: estimateMinutes,
            suggestedDeadline: suggestedDeadline,
            effortLevel: effortLevel,
            adaptsTo: adaptsTo,
            blockedByPremium: blockedByPremium,
            order: order,
            completed: isCompleted,
            blockedReason: blockedReason,
            blockedAt: blockedAt,
            repeatEvery: repeatEvery,
            repeatTimes: repeatTimes,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    /// Actualiza la entidad desde un DTO del servidor
    func update(from dto: StepSyncDTO) {
        stepTitle = dto.title
        descriptionShort = dto.descriptionShort
        descriptionLong = dto.descriptionLong
        estimateMinutes = dto.estimateMinutes
        suggestedDeadline = dto.suggestedDeadline
        effortLevel = dto.effortLevel
        adaptsTo = dto.adaptsTo
        blockedByPremium = dto.blockedByPremium
        order = dto.order
        isCompleted = dto.completed
        // El servidor aún puede no guardar la hora: si no la manda, se conserva la local.
        completedAt = dto.completed ? (dto.completedAt ?? completedAt) : nil
        blockedReason = dto.blockedReason
        blockedAt = dto.blockedAt
        repeatEvery = dto.repeatEvery
        repeatTimes = dto.repeatTimes
        createdAt = dto.createdAt ?? createdAt
        updatedAt = dto.updatedAt ?? updatedAt
        deletedAt = dto.deletedAt
    }

    /// Crea una entidad desde un DTO de sync
    convenience init(fromSync dto: StepSyncDTO, goal: GoalEntity, ownerID: String) {
        self.init(
            id: dto.id ?? UUID(),
            ownerID: ownerID,
            stepTitle: dto.title,
            descriptionShort: dto.descriptionShort,
            descriptionLong: dto.descriptionLong,
            estimateMinutes: dto.estimateMinutes,
            suggestedDeadline: dto.suggestedDeadline,
            effortLevel: dto.effortLevel,
            adaptsTo: dto.adaptsTo,
            blockedByPremium: dto.blockedByPremium,
            order: dto.order,
            isCompleted: dto.completed,
            createdAt: dto.createdAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            deletedAt: dto.deletedAt
        )
        self.goal = goal
        self.blockedReason = dto.blockedReason
        self.blockedAt = dto.blockedAt
        self.completedAt = dto.completed ? dto.completedAt : nil
        self.repeatEvery = dto.repeatEvery
        self.repeatTimes = dto.repeatTimes
    }
}

// MARK: - Repetición

extension StepEntity {
    var repetition: StepRepetition? {
        StepRepetition(every: repeatEvery, times: repeatTimes)
    }

    /// Fechas de cada sesión (la primera es `suggestedDeadline`).
    var sessionDates: [Date] {
        guard let first = suggestedDeadline else { return [] }
        return repetition?.dates(from: first) ?? [first]
    }
}

/// Un paso que se repite: «Cada día · 7 veces», «Cada semana · 4 veces».
struct StepRepetition: Hashable {
    enum Every: String { case day, week }

    let every: Every
    let times: Int

    init?(every: String?, times: Int?) {
        guard let every = every.flatMap(Every.init(rawValue:)), let times, times > 1 else { return nil }
        self.every = every
        self.times = times
    }

    /// «Cada día, durante 2 semanas», «Cada día, durante 5 días», «Una vez por semana, durante 4 semanas».
    var label: String {
        switch every {
        case .day where times % 7 == 0:
            let weeks = times / 7
            return weeks == 1 ? String(localized: "Cada día, durante 1 semana") : String(localized: "Cada día, durante \(weeks) semanas")
        case .day:
            return String(localized: "Cada día, durante \(times) días")
        case .week:
            return String(localized: "Una vez por semana, durante \(times) semanas")
        }
    }

    /// «Día 3 de 14» o «Semana 2 de 4».
    func sessionName(_ index: Int) -> String {
        every == .day ? String(localized: "Día \(index + 1) de \(times)") : String(localized: "Semana \(index + 1) de \(times)")
    }

    func dates(from first: Date, calendar: Calendar = .current) -> [Date] {
        (0..<times).compactMap {
            calendar.date(byAdding: every == .day ? .day : .weekOfYear, value: $0, to: first)
        }
    }

    /// Última sesión: hasta cuándo dura el hábito.
    func lastDate(from first: Date) -> Date? { dates(from: first).last }
}

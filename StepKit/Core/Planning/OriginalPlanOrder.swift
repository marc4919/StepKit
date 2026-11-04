//
//  OriginalPlanOrder.swift
//  StepKit
//
//  El orden en que la IA preparó un Kit (`StepEntity.planPosition`), para volver a él desde «Editar pasos».
//

import Foundation

enum OriginalPlanOrder {
    /// Posición de cada paso en el plan original. Los añadidos después no están.
    static func positions(of kit: GoalEntity) -> [UUID: Int] {
        Dictionary(kit.orderedActiveSteps.compactMap { step in step.planPosition.map { (step.id, $0) } },
                   uniquingKeysWith: { first, _ in first })
    }

    /// `ids` con los pasos del plan en su orden original. Los añadidos después no se mueven de su sitio.
    static func restored(_ ids: [UUID], positions: [UUID: Int]) -> [UUID] {
        var known = ids.filter { positions[$0] != nil }
            .sorted { positions[$0, default: 0] < positions[$1, default: 0] }[...]
        return ids.map { positions[$0] == nil ? $0 : (known.popFirst() ?? $0) }
    }
}

/// Las explicaciones del creador sobran cuando ya se conoce: se quitan tras crear dos Kits.
enum KitCreationHints {
    private static let key = "kitsCreatedCount"
    static var visible: Bool { UserDefaults.standard.integer(forKey: key) < 2 }
    static func kitCreated() { UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key) }
}

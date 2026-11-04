//
//  OriginalPlanOrder.swift
//  StepKit
//
//  El orden en que la IA preparó un Kit, para revisar después los pasos movidos a mano y poder volver a él.
//  Se guarda en este dispositivo, sin campo sincronizado: sin el dato, la revisión funciona como antes.
//

import Foundation

enum OriginalPlanOrder {
    private static func key(_ kit: GoalEntity) -> String { "originalPlanOrder.\(kit.id)" }

    static func record(_ kit: GoalEntity) {
        let positions = Dictionary(uniqueKeysWithValues: kit.orderedActiveSteps.enumerated().map { ($1.id.uuidString, $0 + 1) })
        UserDefaults.standard.set(positions, forKey: key(kit))
    }

    /// Posición de cada paso en el plan original (1 = el primero). Los añadidos después no están.
    static func positions(of kit: GoalEntity) -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: key(kit)) as? [String: Int] ?? [:]
    }

    /// `ids` con los pasos del plan en su orden original. Los añadidos después no se mueven de su sitio.
    static func restored(_ ids: [UUID], positions: [String: Int]) -> [UUID] {
        var known = ids.filter { positions[$0.uuidString] != nil }
            .sorted { positions[$0.uuidString, default: 0] < positions[$1.uuidString, default: 0] }[...]
        return ids.map { positions[$0.uuidString] == nil ? $0 : (known.popFirst() ?? $0) }
    }
}

//
//  KitLogView.swift
//  StepKit
//
//  Registro del Kit (v4.4): avances y bloqueos vinculados a su paso, pasos
//  completados y el inicio del plan, del más reciente al más antiguo.
//

import SwiftUI

struct KitLogView: View {
    let kit: GoalEntity
    let entries: [ProgressEntryEntity]
    let onEdit: (ProgressEntryEntity) -> Void
    let onAddNote: () -> Void

    private struct Item: Identifiable {
        let id: String
        let date: Date
        let symbol: String
        let color: Color
        let title: String
        let text: String
        var stepNumber: Int?
        var entry: ProgressEntryEntity?
    }

    private var items: [Item] {
        var result: [Item] = entries.map { entry in
            let step = kit.orderedActiveSteps.first { $0.id == entry.stepID }
            let blocked = entry.kind == .blocked
            return Item(
                id: "entry-\(entry.id)",
                date: entry.notedAt,
                symbol: blocked ? Symbols.blocked : "circle.lefthalf.filled",
                color: blocked ? .red : .accentColor,
                title: blocked ? "Bloqueo anotado" : "Avance guardado",
                text: entry.note.isEmpty ? "Sin nota." : entry.note,
                stepNumber: step.map { kit.position(of: $0) },
                entry: entry
            )
        }
        // La fecha exacta de completado no se guarda: se usa el último cambio del paso.
        for step in kit.orderedActiveSteps where step.isCompleted {
            result.append(Item(
                id: "done-\(step.id)", date: step.updatedAt, symbol: "checkmark.circle.fill",
                color: MetaTint.done, title: step.stepTitle, text: "Paso completado.",
                stepNumber: kit.position(of: step)
            ))
        }
        if let confirmed = kit.resultConfirmedAt {
            result.append(Item(
                id: "result", date: confirmed, symbol: "checkmark.seal.fill", color: MetaTint.done,
                title: "Confirmaste el resultado", text: kit.kpi.isEmpty ? kit.title : kit.kpi
            ))
        }
        result.sort { $0.date > $1.date }
        result.append(Item(
            id: "start", date: kit.createdAt, symbol: "flag.fill", color: MetaTint.date,
            title: "Tu plan empezó aquí",
            text: [kit.kpi.isEmpty ? nil : kit.kpi,
                   kit.dueDate.map { "fecha deseada \($0.formatted(.dateTime.day().month(.abbreviated)))" }]
                .compactMap { $0 }.joined(separator: " · ")
        ))
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tu recorrido")
                .font(.title3.bold())
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)
            let all = items
            ForEach(Array(all.enumerated()), id: \.element.id) { index, item in
                row(item, last: index == all.count - 1)
            }
            Text("Cada avance queda vinculado a su paso. Guardar avance no completa el paso.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            PlainCard {
                Eyebrow(text: "Notas del Kit", color: .secondary)
                Text("Apuntes generales que no pertenecen a un paso concreto.")
                    .foregroundStyle(.secondary)
                Button("Añadir nota", systemImage: "plus", action: onAddNote)
            }
            .padding(.top, 16)
        }
    }

    private func row(_ item: Item, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                IconChip(symbol: item.symbol, color: item.color, size: 32)
                if !last {
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text([item.date.formatted(.dateTime.day().month(.abbreviated)),
                      item.stepNumber.map { "Paso \($0)" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.title).font(.headline)
                if !item.text.isEmpty {
                    Text(item.text).foregroundStyle(.secondary)
                }
                if let entry = item.entry {
                    Button("Editar nota", systemImage: "pencil") { onEdit(entry) }
                        .font(.subheadline)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 18)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }
}

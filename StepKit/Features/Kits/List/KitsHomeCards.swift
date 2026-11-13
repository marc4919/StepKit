//
//  KitsHomeCards.swift
//  StepKit
//

import SwiftUI
import TipKit
import SwiftData

// MARK: - Tarjeta Continuar

struct ContinueCard: View {
    let kit: GoalEntity
    let lastProgress: ProgressEntryEntity?
    /// Con dos columnas, el paso ya se ve a la derecha: «Continuar» no tendría nada que hacer.
    var isNextStepOpen = false
    let onContinue: () -> Void
    let onOpenKit: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenKit) { header.contentShape(.rect) }
                .buttonStyle(.plain)
                .accessibilityLabel("Kit: \(kit.title)")
                .accessibilityValue(String(localized: "\(kit.completedStepCount) de \(kit.activeStepCount) pasos"))
                .accessibilityHint("Abre el plan del Kit")
                .accessibilityIdentifier("kit.row")
            if lastProgress != nil || kit.nextStep != nil {
                Divider().padding(.top, 6)
            }
            if let entry = lastProgress {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: Symbols.note, color: .accentColor, size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dónde lo dejaste").font(.headline)
                        Text(entry.note).foregroundStyle(.secondary).lineLimit(3)
                        HStack(spacing: 4) {
                            Image(systemName: Symbols.calendar)
                            Text(String(localized: "Último avance · \(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)))"))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let step = kit.nextStep {
                nextStep(step)
            } else {
                Button(action: onOpenKit) {
                    Label("Abrir Kit", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAction)
                .controlSize(.large)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }

    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
            : AnyLayout(HStackLayout(alignment: .top))
        return layout {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Text("CONTINUAR").font(.caption2.weight(.bold)).foregroundStyle(.tint))\(Text("  · último que avanzaste").font(.caption2).foregroundStyle(.secondary))")
                    .fixedSize(horizontal: false, vertical: true)
                Text(kit.title)
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if let date = kit.dueDate {
                    HStack(spacing: 5) {
                        Image(systemName: Symbols.wantedDate)
                        Text("Fecha final · \(PlanGrouping.shortDate(date))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                // La señal de que la cabecera abre el Kit: antes nada lo indicaba.
                Label("Ver Kit", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.top, 2)
            }
            // En vertical (letra de accesibilidad) el separador estiraba la tarjeta y dejaba un hueco vacío.
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if typeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 64)
                    stepCount.font(.body)
                }
            } else {
                VStack(spacing: 10) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 78)
                    stepCount.font(.caption2)
                }
            }
        }
    }

    private var stepCount: some View {
        Text(String(localized: "\(kit.completedStepCount) de \(kit.activeStepCount) pasos"))
            .foregroundStyle(.secondary)
    }

    private func nextStep(_ step: StepEntity) -> some View {
        TintCard(strength: 0.10) {
            HStack(alignment: .top, spacing: 12) {
                NextMark().padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: String(localized: "Paso \(kit.position(of: step)) · \(step.estimateMinutes) min"))
                    Text(step.title)
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if !step.descriptionShort.isEmpty {
                        Text(step.descriptionShort)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            if isNextStepOpen {
                // Un botón desactivado casi no se leía: texto normal sobre el azul, y el ✓ dice el estado.
                Label("Abierto", systemImage: "checkmark")
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.accentColor.opacity(0.25), in: .capsule)
                    .accessibilityIdentifier("kit.continue")
            } else {
                Button(action: onContinue) {
                    Label("Continuar", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAction)
                .controlSize(.large)
                .accessibilityIdentifier("kit.continue")
                .accessibilityHint("Abre el siguiente paso de \(kit.title)")
            }
        }
    }
}

// MARK: - Pasos terminados, resultado por confirmar

struct PendingResultRow: View {
    let kit: GoalEntity

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(MetaTint.done)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(kit.title).font(.headline).foregroundStyle(.primary)
                Text(String(localized: "\(kit.activeStepCount) de \(kit.activeStepCount) pasos · Revisa el resultado"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

private struct PendingResultCard: View {
    let kit: GoalEntity
    @Environment(\.dynamicTypeSize) private var typeSize
    let onReview: () -> Void
    let onBackToPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: String(localized: "Pasos terminados · falta revisar el resultado"), color: MetaTint.done)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kit.title).font(.title2.bold())
                        .accessibilityIdentifier("kit.row")
                        .accessibilityLabel("Kit: \(kit.title)")
                    Text(String(localized: "\(kit.completedStepCount) de \(kit.activeStepCount) pasos terminados"))
                        .foregroundStyle(.secondary)
                    Text("Resultado sin confirmar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MetaTint.done)
                }
            }
            TintCard(tint: MetaTint.done, strength: 0.12) {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(symbol: "flag.checkered", color: MetaTint.done)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resultado por confirmar").font(.headline)
                        Text("Has completado los pasos. Comprueba que tienes lo que buscabas antes de confirmar el resultado.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(action: onReview) {
                    Label("Revisar resultado", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryAction)
                .controlSize(.large)
                .accessibilityIdentifier("result.review")
                Button(action: onBackToPlan) {
                    Text("Volver al plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }
}

// MARK: - Fila de Kit

struct KitHomeRow: View {
    let kit: GoalEntity
    let lastProgress: ProgressEntryEntity?

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if kit.isCompleted {
                    Label(String(localized: "\(kit.activeStepCount) de \(kit.activeStepCount) pasos"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let next = kit.nextStep {
                    Text(next.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !kit.isCompleted {
                    HStack(spacing: 8) {
                        // HStack y no Label: Label separaba el icono del texto más de la cuenta.
                        if let date = kit.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: Symbols.wantedDate)
                                Text(PlanGrouping.shortDate(date))
                            }
                            .foregroundStyle(MetaTint.date)
                        }
                        if let entry = lastProgress {
                            HStack(spacing: 3) {
                                Image(systemName: Symbols.note)
                                Text(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption.weight(.medium))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Estado vacío

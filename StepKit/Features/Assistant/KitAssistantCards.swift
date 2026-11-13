//
//  KitAssistantCards.swift
//  StepKit
//

import SwiftUI
import TipKit
import SwiftData

// MARK: - Tarjetas

/// Cambiar de tema no es un ajuste de este Kit: el asistente sugiere crear otro, ya precargado.
/// Cupo mensual agotado: no es un fallo, y la salida es Pro, igual que al crear un Kit.
struct QuotaReachedCard: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Has usado tus \(PlanLimits.freeCloudAIPerMonth) consultas de este mes")).font(.headline)
            Button(action: onUpgrade) {
                Label("Ver StepKit Pro", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAction)
            .controlSize(.large)
            .accessibilityIdentifier("assistant.upgrade")
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.2)))
    }
}

struct NewKitCard: View {
    let suggestion: AssistResponse.Suggestion
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: String(localized: "Otro Kit"), color: .accentColor)
            if let title = suggestion.title, !title.isEmpty {
                Text(title).font(.headline)
            }
            if let reason = suggestion.reason, !reason.isEmpty {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            }
            Button(action: onCreate) {
                Label("Crear un Kit nuevo con esta idea", systemImage: "plus.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAction)
            .controlSize(.large)
            .accessibilityIdentifier("assistant.createKit")
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.2)))
    }
}

struct ProposalCard: View {
    let proposal: PlanProposal
    var steps: [StepEntity] = []
    let onAccept: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Eyebrow(text: String(localized: "Propuesta") + " · "
                        + (proposal.changes.count == 1 ? String(localized: "1 cambio") : String(localized: "\(proposal.changes.count) cambios")),
                        color: .orange)
                Spacer()
                switch proposal.state {
                case .accepted:
                    Label("Aplicada", systemImage: "checkmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.green)
                case .discarded:
                    Label("Descartada", systemImage: "xmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                case .superseded:
                    Label("Sustituida por otra más reciente", systemImage: "arrow.uturn.down.circle")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                case .pending:
                    EmptyView()
                }
            }
            Text(proposal.title).font(.headline)
            // Los cambios concretos se ven siempre, también una vez aplicada: son lo que de verdad ha
            // pasado en el plan, por encima de lo que diga el resumen. Al aplicarse van recibiendo su check.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(proposal.changes) { change in
                    if proposal.state == .accepted, !change.partStepIDs.isEmpty {
                        // Una división aplicada: cada parte es un paso y se abre por separado.
                        ForEach(parts(for: change)) { part in
                            NavigationLink {
                                StepDetailView(stepEntity: part, stepNumber: part.goal?.position(of: part) ?? 1)
                            } label: {
                                partRow(part)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Abre este paso")
                            .accessibilityIdentifier("proposal.openStep")
                        }
                    } else if let step = openableStep(for: change) {
                        // Con destino propio: uno por valor se apilaría por detrás del chat, que no está en la ruta de la pila.
                        NavigationLink {
                            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
                        } label: {
                            changeRow(change, opens: true)
                        }
                            .buttonStyle(.plain)
                            .accessibilityHint("Abre este paso")
                            .accessibilityIdentifier("proposal.openStep")
                    } else {
                        changeRow(change, opens: false)
                    }
                }
            }
            .animation(.snappy, value: proposal.appliedChangeIDs)
            if proposal.state == .pending {
                Label(proposal.impact, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if proposal.state == .pending, !proposal.applying {
                HStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("Aceptar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primaryAction)
                    .accessibilityIdentifier("proposal.accept")
                    .accessibilityHint("Aplica los cambios propuestos al Kit")
                    Button(action: onDiscard) {
                        Text("Descartar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("proposal.discard")
                    .accessibilityHint("Deja el Kit como está")
                }
                .controlSize(.large)
                Text(proposal.changes.count > 1
                     ? String(localized: "Los \(proposal.changes.count) cambios se aplican o se descartan juntos para que el plan siga en orden.")
                     : String(localized: "Solo cambia este paso."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                // Aceptar o descartar no son las únicas opciones: también se puede hablar.
                Label("¿No te convence? Escríbeme abajo y lo ajustamos.", systemImage: "text.bubble")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(proposal.state == .pending ? 0.08 : 0.04), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(proposal.state == .pending ? 0.25 : 0.12)))
        .animation(.default, value: proposal.state)
    }

    /// Una vez aplicada, cada cambio lleva a su paso, si sigue en el plan.
    private func openableStep(for change: ProposedStepChange) -> StepEntity? {
        guard proposal.state == .accepted, let id = change.stepID else { return nil }
        return steps.first { $0.id == id }
    }

    private func parts(for change: ProposedStepChange) -> [StepEntity] {
        change.partStepIDs.compactMap { id in steps.first { $0.id == id } }
    }

    private func partRow(_ step: StepEntity) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "square.split.2x1").foregroundStyle(Color.accentColor).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Paso \(step.goal?.position(of: step) ?? 1) · \(step.stepTitle)")).font(.subheadline.weight(.medium))
                Text(String(localized: "\(step.estimateMinutes) min")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Aplicado")
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func changeRow(_ change: ProposedStepChange, opens: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: change.symbol)
                .foregroundStyle(change.to != nil ? MetaTint.date : Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(change.stepLabel).font(.subheadline.weight(.medium))
                if let to = change.to {
                    HStack(spacing: 6) {
                        if let from = change.from {
                            Text(from.formatted(.dateTime.day().month(.abbreviated)))
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(to.formatted(.dateTime.day().month(.abbreviated)))
                            .fontWeight(.semibold)
                            .foregroundStyle(MetaTint.date)
                    }
                    .font(.caption)
                }
                if let detail = change.detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                if !change.parts.isEmpty {
                    NumberedPartsList(parts: change.parts).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            if proposal.appliedChangeIDs.contains(change.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Aplicado")
            }
            if opens {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Partes de un paso dividido, numeradas y una por línea. Entran una tras otra, como los pasos al crear un Kit.
private struct NumberedPartsList: View {
    let parts: [String]
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                    Text(part).fixedSize(horizontal: false, vertical: true)
                }
                .modifier(Reveal(shown: shown, order: index))
            }
        }
        .font(.subheadline)
        .onAppear { shown = true }
    }
}

struct ResolveBlockCard: View {
    let step: StepEntity
    let onResolve: () -> Void

    var body: some View {
        TintCard(tint: .red, strength: 0.08) {
            HStack(alignment: .top, spacing: 12) {
                IconChip(symbol: Symbols.blocked, color: .red)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Paso bloqueado").font(.headline)
                    Text(step.blockedReason ?? "").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button(action: onResolve) {
                Text("Ya lo tengo, seguir").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("assistant.resolveBlock")
        }
    }
}

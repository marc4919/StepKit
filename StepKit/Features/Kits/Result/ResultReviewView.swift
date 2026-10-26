//
//  ResultReviewView.swift
//  StepKit
//
//  v4.4: terminar todos los pasos no confirma el resultado. El usuario lo revisa
//  contra lo que quería conseguir (KPI del Kit) y lo confirma explícitamente.
//

import SwiftUI
import SwiftData

struct ResultReviewView: View {
    let kit: GoalEntity
    var onBackToPlan: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager
    @State private var achieved = false
    @State private var saveFailed = false
    @Query(sort: \ProgressEntryEntity.notedAt) private var allEntries: [ProgressEntryEntity]
    @Query private var allSessions: [WorkSessionEntity]

    private var summary: JourneySummary {
        JourneySummary(kit: kit,
                       entries: allEntries.filter { $0.kitID == kit.id && $0.deletedAt == nil },
                       sessions: allSessions.filter { $0.kitID == kit.id && $0.deletedAt == nil })
    }

    var body: some View {
        Group {
            if kit.resultConfirmedAt != nil {
                ResultConfirmedContent(kit: kit, summary: summary) { dismiss() } onReopen: { setConfirmed(false) }
            } else {
                review
            }
        }
        .readableContentWidth()
        .navigationTitle(kit.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("No se pudo guardar", isPresented: $saveFailed) {
            Button("Aceptar", role: .cancel) {}
        }
    }

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 92)
                    Text("\(kit.completedStepCount) de \(kit.activeStepCount) pasos terminados.\nEl anillo cuenta pasos, no el resultado.")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                JourneyCard(summary: summary)
                Text("¿Ya tienes el resultado que buscabas?")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                PlainCard {
                    Eyebrow(text: "Lo que querías conseguir", color: .secondary)
                    Toggle(isOn: $achieved) {
                        Text(kit.kpi.isEmpty ? kit.title : kit.kpi)
                    }
                    .accessibilityIdentifier("result.achieved")
                }
                Label("Completar los pasos no confirma por sí solo el resultado.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .background(alignment: .top) { BrandGlow() }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    setConfirmed(true)
                } label: {
                    Text("Confirmar resultado").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!achieved)
                .accessibilityIdentifier("result.confirm")
                Button {
                    if let onBackToPlan { onBackToPlan() } else { dismiss() }
                } label: {
                    Text("Volver al plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if !achieved {
                    Text("Marca el resultado cuando lo hayas comprobado.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func setConfirmed(_ confirmed: Bool) {
        do {
            try withAnimation {
                try ProgressLog.setResultConfirmed(confirmed, kit: kit, context: modelContext)
            }
            syncManager?.handleDataChange()
            if confirmed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                achieved = false
            }
        } catch {
            saveFailed = true
        }
    }
}

private struct ResultConfirmedContent: View {
    let kit: GoalEntity
    let summary: JourneySummary
    let onDone: () -> Void
    let onReopen: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    OrbitMark(height: 220).padding(.horizontal, 24)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white, .green)
                        .offset(x: 95, y: -30)
                        .accessibilityHidden(true)
                }
                .padding(.top, 24)
                Text("\(kit.title)\nestá listo")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Has confirmado el resultado.").foregroundStyle(.secondary)
                PlainCard {
                    Label(kit.kpi.isEmpty ? kit.title : kit.kpi, systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                    if let date = kit.resultConfirmedAt {
                        Text("Confirmado por ti · \(date.formatted(.dateTime.day().month(.abbreviated))) · \(kit.completedStepCount) de \(kit.activeStepCount) pasos")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                JourneyCard(summary: summary)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background { EntryBackground() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onDone) {
                    Text("Volver a Mis Kits").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Reabrir resultado", action: onReopen)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

/// Lo que has hecho para llegar hasta aquí: tiempo, constancia y el camino de tus notas.
struct JourneySummary {
    let days: Int
    let plannedDays: Int
    let minutes: Int
    let notes: Int
    let blocks: Int
    let sessions: Int
    let steps: Int
    let firstNote: ProgressEntryEntity?
    let lastNote: ProgressEntryEntity?

    init(kit: GoalEntity, entries: [ProgressEntryEntity], sessions: [WorkSessionEntity]) {
        let end = kit.resultConfirmedAt ?? .now
        days = max(1, Calendar.current.dateComponents([.day], from: kit.createdAt, to: end).day ?? 1)
        plannedDays = kit.horizonDays
        minutes = kit.orderedActiveSteps.filter(\.isCompleted)
            .reduce(0) { $0 + $1.estimateMinutes * ($1.repetition?.times ?? 1) }
        let written = entries.filter { $0.kind == .progress && !$0.note.isEmpty }
        notes = written.count
        blocks = entries.filter { $0.kind == .blocked }.count
        self.sessions = sessions.count
        steps = kit.completedStepCount
        firstNote = written.first
        lastNote = written.count > 1 ? written.last : nil
    }

    var timeText: String {
        minutes >= 90 ? "≈ \(Int((Double(minutes) / 60).rounded())) h" : "\(minutes) min"
    }
}

struct JourneyCard: View {
    let summary: JourneySummary

    var body: some View {
        PlainCard {
            Eyebrow(text: "Tu recorrido", color: .secondary)
            // Solo lo que aporta: nada de contadores a cero.
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                      alignment: .leading, spacing: 14) {
                ForEach(stats, id: \.detail) { item in
                    stat(symbol: item.symbol, tint: item.tint, value: item.value, detail: item.detail)
                }
            }
            if let first = summary.firstNote {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    quote(title: "Al empezar", entry: first)
                    if let last = summary.lastNote {
                        quote(title: "Tu último avance", entry: last)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private struct Stat {
        let symbol: String
        let tint: Color
        let value: String
        let detail: String
    }

    private var stats: [Stat] {
        var items = [
            Stat(symbol: Symbols.calendar, tint: MetaTint.date,
                 value: summary.days == 1 ? "1 día" : "\(summary.days) días",
                 detail: summary.plannedDays > 0 ? "de \(summary.plannedDays) previstos" : "desde que empezaste"),
            Stat(symbol: Symbols.time, tint: MetaTint.time, value: summary.timeText, detail: "de trabajo en tus pasos"),
            Stat(symbol: "checkmark.circle", tint: MetaTint.done, value: "\(summary.steps)",
                 detail: summary.steps == 1 ? "paso completado" : "pasos completados"),
        ]
        if summary.notes > 0 {
            items.append(Stat(symbol: Symbols.note, tint: .orange, value: "\(summary.notes)",
                              detail: summary.notes == 1 ? "avance anotado" : "avances anotados"))
        }
        if summary.blocks > 0 {
            items.append(Stat(symbol: Symbols.blocked, tint: .red, value: "\(summary.blocks)",
                              detail: summary.blocks == 1 ? "bloqueo superado" : "bloqueos superados"))
        }
        if summary.sessions > 0 {
            items.append(Stat(symbol: Symbols.session, tint: .accentColor, value: "\(summary.sessions)",
                              detail: summary.sessions == 1 ? "sesión reservada" : "sesiones reservadas"))
        }
        return items
    }

    private func stat(symbol: String, tint: Color, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            IconChip(symbol: symbol, color: tint, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quote(title: String, entry: ProgressEntryEntity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(Color.accentColor.opacity(0.5)).frame(width: 3).clipShape(.capsule)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) · \(entry.notedAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.note).font(.subheadline)
            }
        }
    }
}

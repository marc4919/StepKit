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
    @Environment(\.returnToKits) private var returnToKits
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
                ResultConfirmedContent(kit: kit, summary: summary) {
                    // A Mis Kits de verdad, no solo una pantalla atrás.
                    if let returnToKits { returnToKits() } else { dismiss() }
                } onReopen: { setConfirmed(false) }
            } else {
                review.readableContentWidth()
            }
        }
        .navigationTitle(kit.title)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarSmoothly()
        .alert("No se pudo guardar", isPresented: $saveFailed) {
            Button("Aceptar", role: .cancel) {}
        }
    }

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ProgressRing(done: kit.completedStepCount, total: kit.activeStepCount, size: 92)
                    Text(String(localized: "\(kit.completedStepCount) de \(kit.activeStepCount) pasos terminados.\nEl anillo cuenta pasos, no el resultado."))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                JourneyCard(summary: summary)
                Text("¿Ya tienes el resultado que buscabas?")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                PlainCard {
                    Eyebrow(text: String(localized: "Lo que querías conseguir"), color: .secondary)
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
            .padding(.top, 12)
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

/// «Kit está listo». En vertical, una columna; en pantallas anchas y apaisadas (Duo abierto,
/// iPhone en horizontal), la celebración a la izquierda y el recorrido a la derecha. Los botones
/// van sobre una barra para que el título nunca quede debajo de ellos.
private struct ResultConfirmedContent: View {
    let kit: GoalEntity
    let summary: JourneySummary
    let onDone: () -> Void
    let onReopen: () -> Void
    @State private var size = CGSize(width: 390, height: 800)

    /// El alto medido ya descuenta la barra de navegación y los botones: solo se pasa a dos
    /// columnas cuando la pantalla es claramente más ancha que alta.
    private var sideBySide: Bool {
        TwoColumnLayout.fits(size) || (size.width > size.height * 1.3 && size.height < 500)
    }

    /// La ilustración se adapta a la altura: en el exterior del Duo o en horizontal es más baja.
    private var artHeight: CGFloat {
        sideBySide ? min(200, max(100, size.height * 0.28)) : min(200, max(120, size.height * 0.24))
    }

    var body: some View {
        Group {
            if sideBySide {
                HStack(alignment: .center, spacing: 32) {
                    ScrollView {
                        hero
                            .frame(maxWidth: .infinity, minHeight: size.height * 0.7)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    ScrollView {
                        details
                            .padding(.vertical, 20)
                            .frame(minHeight: size.height * 0.7)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxWidth: 460)
                }
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        hero
                        details
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background { EntryBackground() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(action: onDone) {
                    Text("Volver a Mis Kits").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Reabrir resultado", action: onReopen)
                    .font(.subheadline)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            OrbitMark(height: artHeight)
                .frame(width: artHeight * 1.3)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: artHeight * 0.2))
                        .foregroundStyle(.white, .green)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 4)
            Text(String(localized: "\(kit.title)\nestá listo"))
                .font(size.height < 400 ? .title2.bold() : size.height < 720 ? .title.bold() : .largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Has confirmado el resultado.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var details: some View {
        VStack(spacing: 16) {
            PlainCard {
                Label(kit.kpi.isEmpty ? kit.title : kit.kpi, systemImage: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                if let date = kit.resultConfirmedAt {
                    Text(String(localized: "Confirmado por ti · \(date.formatted(.dateTime.day().month(.abbreviated))) · \(kit.completedStepCount) de \(kit.activeStepCount) pasos"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            JourneyCard(summary: summary)
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
    }

    var timeText: String {
        minutes >= 90 ? String(localized: "≈ \(Int((Double(minutes) / 60).rounded())) h") : String(localized: "\(minutes) min")
    }
}

struct JourneyCard: View {
    let summary: JourneySummary

    var body: some View {
        PlainCard {
            Eyebrow(text: String(localized: "Tu recorrido"), color: .secondary)
            // Solo lo que aporta: nada de contadores a cero.
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                      alignment: .leading, spacing: 14) {
                ForEach(stats, id: \.detail) { item in
                    stat(symbol: item.symbol, tint: item.tint, value: item.value, detail: item.detail)
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
                 value: summary.days == 1 ? String(localized: "1 día") : String(localized: "\(summary.days) días"),
                 detail: summary.plannedDays > 0 ? String(localized: "de \(summary.plannedDays) previstos") : String(localized: "desde que empezaste")),
            Stat(symbol: Symbols.time, tint: MetaTint.time, value: summary.timeText, detail: String(localized: "de trabajo en tus pasos")),
            Stat(symbol: "checkmark.circle", tint: MetaTint.done, value: "\(summary.steps)",
                 detail: summary.steps == 1 ? String(localized: "paso completado") : String(localized: "pasos completados")),
        ]
        if summary.notes > 0 {
            items.append(Stat(symbol: Symbols.note, tint: .orange, value: "\(summary.notes)",
                              detail: summary.notes == 1 ? String(localized: "avance anotado") : String(localized: "avances anotados")))
        }
        if summary.blocks > 0 {
            items.append(Stat(symbol: Symbols.blocked, tint: .red, value: "\(summary.blocks)",
                              detail: summary.blocks == 1 ? String(localized: "bloqueo superado") : String(localized: "bloqueos superados")))
        }
        if summary.sessions > 0 {
            items.append(Stat(symbol: Symbols.session, tint: .accentColor, value: "\(summary.sessions)",
                              detail: summary.sessions == 1 ? String(localized: "sesión reservada") : String(localized: "sesiones reservadas")))
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
}


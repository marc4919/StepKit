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

    var body: some View {
        Group {
            if kit.resultConfirmedAt != nil {
                ResultConfirmedContent(kit: kit) { dismiss() } onReopen: { setConfirmed(false) }
            } else {
                review
            }
        }
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

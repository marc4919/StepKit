//
//  KitCreationFormContent.swift
//  StepKit
//
//  Crear Kit v4.4: formulario del sistema con iconos de color y el recorrido pequeño.
//  El plan se revisa antes de aceptarlo.
//

import SwiftUI

struct KitCreationFormContent: View {
    @Binding var description: String
    @Binding var dueDate: Date
    @Binding var inconveniences: String
    @Binding var doneWhen: String
    @Binding var startingPoint: String
    @Binding var sessionsPerWeek: Int
    @Binding var sessionMinutes: Int
    @Binding var oneSitting: Bool

    var focusedField: FocusState<KitCreatorField?>.Binding
    let todayStart: Date
    let isDateInPast: Bool
    let isFormValid: Bool
    let onCreate: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    OrbitMark(height: 86).frame(maxWidth: 240)
                    Text("¿Qué quieres conseguir?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Revisarás el plan antes de aceptarlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                field("target", .accentColor, "Resultado", placeholder: "Ej.: Correr 5 km sin parar",
                      text: $description, focus: .description, identifier: "kitCreator.description")
                field("checklist", .green, "Cómo sabré que está listo (opcional)",
                      placeholder: "Ej.: Los corro en menos de 35 min", text: $doneWhen, focus: .doneWhen)
                field("flag.fill", .pink, "Punto de partida (opcional)",
                      placeholder: "Ej.: Ahora aguanto 10 min seguidos", text: $startingPoint, focus: .startingPoint)
                field(Symbols.risk, .orange, "Qué te puede frenar (opcional)",
                      placeholder: "Ej.: Trabajo a turnos, me duele la rodilla", text: $inconveniences, focus: .obstacles)
            }
            Section {
                Toggle(isOn: $oneSitting.animation(.smooth)) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("En una sola sesión")
                            Text("Para algo que harás de una vez, como una receta o un montaje.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        IconChip(symbol: "bolt.fill", color: .orange, size: 28)
                    }
                }
                .accessibilityIdentifier("kitCreator.oneSitting")
                if !oneSitting {
                    Stepper(value: $sessionsPerWeek, in: 1...14) {
                        Label {
                            Text(sessionsPerWeek == 1 ? "1 sesión por semana" : "\(sessionsPerWeek) sesiones por semana")
                        } icon: {
                            IconChip(symbol: "repeat", color: MetaTint.time, size: 28)
                        }
                    }
                }
                Picker(selection: $sessionMinutes) {
                    ForEach(durations, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
                } label: {
                    Label { Text(oneSitting ? "Tiempo disponible" : "Cada sesión") } icon: {
                        IconChip(symbol: "timer", color: MetaTint.time, size: 28)
                    }
                }
                DatePicker(selection: $dueDate, in: todayStart..., displayedComponents: .date) {
                    Label { Text("Fecha deseada") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
                }
                .accessibilityIdentifier("kitCreator.dueDate")
            } header: {
                Text("Tu tiempo")
            } footer: {
                Text("La fecha es orientativa. Podrás ajustar el plan y tu tiempo después.")
            }
            Section {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCreate()
                } label: {
                    Text("Preparar plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("kitCreator.create")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: oneSitting) { _, _ in
            // Se mantiene el tiempo elegido; si no existe en la otra lista, el más cercano (sin saltos bruscos).
            if !durations.contains(sessionMinutes),
               let nearest = durations.min(by: { abs($0 - sessionMinutes) < abs($1 - sessionMinutes) }) {
                sessionMinutes = nearest
            }
        }
    }

    /// Desde ratos cortos hasta una mañana entera.
    private var durations: [Int] {
        oneSitting ? [10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480] : [10, 15, 20, 30, 45, 60, 90, 120, 180]
    }

    private func field(
        _ symbol: String,
        _ color: Color,
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        focus: KitCreatorField,
        identifier: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(symbol: symbol, color: color, size: 28).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused(focusedField, equals: focus)
                    .accessibilityIdentifier(identifier ?? "")
                    .accessibilityLabel(title)
            }
        }
    }
}

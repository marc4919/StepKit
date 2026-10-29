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

    @State private var width: CGFloat = 0
    /// Interior del iPhone Duo, iPad o iPhone en horizontal: dos columnas en vez de una tira estirada.
    private var twoColumns: Bool { TwoColumnLayout.fits(CGSize(width: width, height: height)) }
    @State private var height: CGFloat = 0
    private var landscape: Bool { width > height }

    var body: some View {
        Group {
            if twoColumns {
                // El título abarca las dos columnas; debajo, el objetivo y el tiempo lado a lado.
                VStack(spacing: 0) {
                    headerContent.padding(.top, 8)
                    // 24 pt a los lados y 40 pt entre columnas, sin recortar las tarjetas.
                    HStack(alignment: .top, spacing: 24) {
                        Form { goalSection }
                        Form {
                            timeSection
                            createSection
                        }
                    }
                    .contentMargins(.horizontal, 8, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 1100)
                }
                .balancedHorizontalSafeArea()
                .background(Color(.systemGroupedBackground))
            } else {
                ScrollViewReader { proxy in
                    Form {
                        headerSection
                        goalSection
                        timeSection
                        createSection
                    }
                    // Al tocar un campo, la lista se desplaza con suavidad hasta él, por encima del teclado.
                    .onChange(of: focusedField.wrappedValue) { _, field in
                        guard let field else { return }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            withAnimation(.smooth(duration: 0.45)) {
                                proxy.scrollTo(field, anchor: UnitPoint(x: 0.5, y: 0.25))
                            }
                        }
                    }
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { width = $0.width; height = $0.height }
        .scrollDismissesKeyboard(.interactively)
        // Al tocar un interruptor, un selector o la fecha, el teclado se retira: ya no estás escribiendo.
        .onChange(of: sessionsPerWeek) { _, _ in dismissKeyboard() }
        .onChange(of: sessionMinutes) { _, _ in dismissKeyboard() }
        .onChange(of: dueDate) { _, _ in dismissKeyboard() }
        .onChange(of: oneSitting) { _, _ in
            dismissKeyboard()
            // Se mantiene el tiempo elegido; si no existe en la otra lista, el más cercano (sin saltos bruscos).
            if !durations.contains(sessionMinutes),
               let nearest = durations.min(by: { abs($0 - sessionMinutes) < abs($1 - sessionMinutes) }) {
                sessionMinutes = nearest
            }
        }
    }

    @ViewBuilder private var headerSection: some View {
        Section {
            headerContent.listRowBackground(Color.clear)
        }
    }

    private var headerContent: some View {
        VStack(spacing: 8) {
            // En horizontal la pantalla es baja: el dibujo se reduce para dejar sitio al formulario.
            if !landscape { OrbitMark(height: 86).frame(maxWidth: 240) }
            Text("¿Qué quieres conseguir?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Revisarás el plan antes de aceptarlo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Los tres campos opcionales van plegados bajo una fila: la primera pantalla queda con el
    /// resultado y el tiempo. Si ya hay algo escrito en ellos (al volver de una vista previa), se ven.
    @State private var showsContext = false
    private var hasContext: Bool {
        ![doneWhen, startingPoint, inconveniences].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @ViewBuilder private var goalSection: some View {
        Section {
            field("target", .accentColor, String(localized: "Resultado"), placeholder: String(localized: "Ej.: Correr 5 km sin parar"),
                  text: $description, focus: .description, next: showsContext ? .doneWhen : nil, identifier: "kitCreator.description")
            Button {
                withAnimation(.smooth(duration: 0.4)) { showsContext.toggle() }
                if !showsContext, [.doneWhen, .startingPoint, .obstacles].contains(focusedField.wrappedValue) {
                    focusedField.wrappedValue = nil
                }
            } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "text.badge.plus", color: .secondary, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(showsContext ? String(localized: "Menos contexto") : String(localized: "Añadir contexto (opcional)"))
                        if !showsContext {
                            Text("Cómo sabrás que está listo, de dónde partes, qué te puede frenar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showsContext ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("kitCreator.context")
            if showsContext {
                field("checklist", .green, String(localized: "Cómo sabré que está listo (opcional)"),
                      placeholder: String(localized: "Ej.: Los corro en menos de 35 min"), text: $doneWhen, focus: .doneWhen, next: .startingPoint)
                field("flag.fill", .pink, String(localized: "Punto de partida (opcional)"),
                      placeholder: String(localized: "Ej.: Ahora aguanto 10 min seguidos"), text: $startingPoint, focus: .startingPoint, next: .obstacles)
                field(Symbols.risk, .orange, String(localized: "Qué te puede frenar (opcional)"),
                      placeholder: String(localized: "Ej.: Trabajo a turnos, me duele la rodilla"), text: $inconveniences, focus: .obstacles)
            }
        } header: {
            Text("Tu objetivo")
        }
        .onAppear { if hasContext { showsContext = true } }
    }

    @ViewBuilder private var timeSection: some View {
        Section {
            Toggle(isOn: $oneSitting.animation(.smooth(duration: 0.5))) {
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
                        Text(sessionsPerWeek == 1 ? String(localized: "1 sesión por semana") : String(localized: "\(sessionsPerWeek) sesiones por semana"))
                    } icon: {
                        IconChip(symbol: "repeat", color: MetaTint.time, size: 28)
                    }
                }
                // La fila se pliega y se funde a la vez, sin aparecer ni desaparecer de golpe.
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).animation(.smooth(duration: 0.5).delay(0.05)),
                    removal: .opacity.combined(with: .move(edge: .top)).animation(.smooth(duration: 0.35))))
            }
            Picker(selection: $sessionMinutes) {
                ForEach(durations, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
            } label: {
                Label {
                    Text(oneSitting ? String(localized: "Tiempo disponible") : String(localized: "Cada sesión"))
                        .contentTransition(.opacity)
                } icon: {
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
    }

    /// Cambiar un control que no es de texto retira el teclado, para que no tape el formulario.
    /// (Sin gestos añadidos a los controles: un TapGesture simultáneo bloqueaba el interruptor.)
    private func dismissKeyboard() {
        focusedField.wrappedValue = nil
    }

    @ViewBuilder private var createSection: some View {
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
        next: KitCreatorField? = nil,
        identifier: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(symbol: symbol, color: color, size: 28).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused(focusedField, equals: focus)
                    // Intro no hace salto de línea: pasa al campo siguiente (y en el último cierra el teclado).
                    .submitLabel(next == nil ? .done : .next)
                    .onChange(of: text.wrappedValue) { _, value in
                        guard value.contains("\n") else { return }
                        text.wrappedValue = value.replacingOccurrences(of: "\n", with: "")
                        withAnimation(.smooth) { focusedField.wrappedValue = next }
                    }
                    .accessibilityIdentifier(identifier ?? "")
                    .accessibilityLabel(title)
            }
        }
        .id(focus)
    }
}

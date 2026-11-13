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
    @Binding var dueDate: Date?
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
    /// A mano: la persona añade los pasos. Se ocultan las filas que solo usa la IA para repartir el plan.
    var manual = false

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
            // Algo más abajo y pegada al formulario: suelta arriba parecía de otra pantalla.
            headerContent
                .padding(.top, 18)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
        .listSectionSpacing(14)
    }

    private var headerContent: some View {
        VStack(spacing: 8) {
            // En horizontal la pantalla es baja: el dibujo se reduce para dejar sitio al formulario.
            if !landscape { OrbitMark(height: 86, travel: manual ? 1 : 0).frame(maxWidth: 240) }
            Text("¿Qué quieres conseguir?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            // Siempre visible: dice en qué modo estás. Cambia con un fundido al tocar el selector.
            Text(manual ? String(localized: "Tú añades los pasos") : String(localized: "La IA propone los pasos; tú los revisas"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .id(manual)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .animation(.formReveal, value: manual)
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
                withAnimation(.formReveal) { showsContext.toggle() }
                if !showsContext, [.doneWhen, .startingPoint, .obstacles].contains(focusedField.wrappedValue) {
                    focusedField.wrappedValue = nil
                }
            } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "text.badge.plus", color: .secondary, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(showsContext ? String(localized: "Ocultar contexto") : String(localized: "Añadir contexto (opcional)"))
                        if !showsContext, KitCreationHints.visible {
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
            .accessibilityHint(showsContext ? String(localized: "Oculta los campos de contexto") : String(localized: "Muestra más campos para describir tu objetivo"))
            if showsContext {
                field("checklist", .green, String(localized: "Cómo sabré que está listo (opcional)"),
                      placeholder: String(localized: "Ej.: Los corro en menos de 35 min"), text: $doneWhen, focus: .doneWhen, next: .startingPoint)
                    .transition(.formRow)
                field("flag.fill", .pink, String(localized: "Punto de partida (opcional)"),
                      placeholder: String(localized: "Ej.: Ahora aguanto 10 min seguidos"), text: $startingPoint, focus: .startingPoint, next: .obstacles)
                    .transition(.formRow)
                field(Symbols.risk, .orange, String(localized: "Qué te puede frenar (opcional)"),
                      placeholder: String(localized: "Ej.: Trabajo a turnos, me duele la rodilla"), text: $inconveniences, focus: .obstacles)
                    .transition(.formRow)
            }
        } header: {
            Text("Tu objetivo")
        }
        .onAppear { if hasContext { showsContext = true } }
    }

    /// Con menos de una semana de plazo no hay semanas que repartir: el contador habla de hoy o del total.
    private var sessionsLabel: String {
        let days = dueDate.map { Calendar.current.dateComponents([.day], from: todayStart, to: Calendar.current.startOfDay(for: $0)).day ?? 7 } ?? 7
        if days <= 0 {
            return sessionsPerWeek == 1 ? String(localized: "Hasta 1 sesión hoy") : String(localized: "Hasta \(sessionsPerWeek) sesiones hoy")
        }
        if days < 7 {
            return sessionsPerWeek == 1 ? String(localized: "Hasta 1 sesión en total") : String(localized: "Hasta \(sessionsPerWeek) sesiones en total")
        }
        return sessionsPerWeek == 1 ? String(localized: "Hasta 1 sesión por semana") : String(localized: "Hasta \(sessionsPerWeek) sesiones por semana")
    }

    @ViewBuilder private var timeSection: some View {
        Section {
            // Primero la fecha: lo que cambia al elegirla queda siempre debajo, nunca encima.
            KitDueDateField(dueDate: $dueDate, todayStart: todayStart)
            if !manual { planningRows }
        } header: {
            Text("Tu tiempo")
        }
    }

    /// Lo que la IA necesita para repartir el plan. A mano no hace falta: los pasos los pone la persona.
    @ViewBuilder private var planningRows: some View {
        Group {
            Picker("¿Cómo lo harás?", selection: Binding(
                get: { oneSitting ? 0 : 1 },
                set: { oneSitting = $0 == 0 }
            ).animation(.formReveal)) {
                Text("De una vez").tag(0)
                Text("Poco a poco").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("¿Cómo lo harás?")
            .accessibilityIdentifier("kitCreator.oneSitting")
            if !oneSitting {
                Stepper(value: $sessionsPerWeek, in: 1...14) {
                    Label {
                        // «Hasta»: es la disponibilidad que tiene en cuenta el plan, no un horario que vaya a llenar.
                        Text(sessionsLabel).contentTransition(.numericText())
                    } icon: {
                        IconChip(symbol: "repeat", color: MetaTint.time, size: 28)
                    }
                }
                .transition(.formRow)
            }
            Picker(selection: $sessionMinutes) {
                ForEach(durations, id: \.self) { Text(KitCreatorViewModel.durationText($0)).tag($0) }
            } label: {
                Label {
                    Text(oneSitting ? String(localized: "Tiempo disponible") : String(localized: "Tiempo por sesión"))
                        .contentTransition(.opacity)
                } icon: {
                    IconChip(symbol: "timer", color: MetaTint.time, size: 28)
                }
            }
        }
        .transition(.formRow)
    }

    /// Cambiar un control que no es de texto retira el teclado, para que no tape el formulario.
    /// (Sin gestos añadidos a los controles: un TapGesture simultáneo bloqueaba el interruptor.)
    private func dismissKeyboard() {
        focusedField.wrappedValue = nil
    }

    private var missingField: String? {
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Escribe qué quieres conseguir para continuar.")
        }
        return dueDate == nil ? String(localized: "Elige una fecha para continuar.") : nil
    }

    @ViewBuilder private var createSection: some View {
        Section {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onCreate()
            } label: {
                Text(manual ? String(localized: "Crear Kit") : String(localized: "Preparar plan"))
                    .contentTransition(.interpolate)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAction)
            .controlSize(.large)
            .disabled(!isFormValid)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .accessibilityHint(missingField ?? "")
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
                // El ejemplo va aparte para que parta líneas con letra grande; el del sistema se recorta.
                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(Color(.placeholderText))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: text, axis: .vertical)
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
        }
        .id(focus)
    }
}

// MARK: - Filas que aparecen y desaparecen

/// La misma animación para todo lo que se despliega en el formulario: la fila se pliega y se funde
/// a la vez, sin aparecer ni desaparecer de golpe.
extension Animation {
    static let formReveal = Animation.smooth(duration: 0.5)
}

extension AnyTransition {
    /// Un contenido sustituye a otro en el mismo sitio: lo viejo se va rápido y lo nuevo entra un
    /// instante después, sin pisarse. Es el cambio de «Dando forma a tu Kit».
    static var contentSwap: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.25)),
            removal: .opacity.animation(.easeIn(duration: 0.2))
        )
    }

    static var formRow: AnyTransition {
        // Un recorrido algo mayor que la propia fila, para que se note que baja desde arriba.
        let travel = AnyTransition.opacity.combined(with: .move(edge: .top)).combined(with: .offset(y: -18))
        return .asymmetric(
            insertion: travel.animation(.smooth(duration: 0.5).delay(0.05)),
            removal: travel.animation(.smooth(duration: 0.35)))
    }
}

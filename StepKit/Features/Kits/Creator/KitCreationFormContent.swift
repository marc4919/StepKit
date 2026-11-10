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
    /// Crear el Kit a mano, sin IA.
    var onStartFromScratch: (() -> Void)? = nil
    var startFromScratchTitle = LocalizedStringKey("Empezar de cero")
    var canStartFromScratch = true

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
            if KitCreationHints.visible {
                Text("Revisarás el plan antes de aceptarlo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
        } header: {
            Text("Tu tiempo")
        }
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
                Text("Preparar plan").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryAction)
            .controlSize(.large)
            .disabled(!isFormValid)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .accessibilityHint(missingField ?? "")
            .accessibilityIdentifier("kitCreator.create")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let onStartFromScratch {
                    Button(action: onStartFromScratch) {
                        Text(startFromScratchTitle).frame(minHeight: 44)
                    }
                        .disabled(!canStartFromScratch)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .accessibilityHint("Crea el Kit a mano, sin IA")
                        .accessibilityIdentifier("kitCreator.fromScratch")
                }
            }
            .padding(.top, 4)
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
    static var formRow: AnyTransition {
        // Un recorrido algo mayor que la propia fila, para que se note que baja desde arriba.
        let travel = AnyTransition.opacity.combined(with: .move(edge: .top)).combined(with: .offset(y: -18))
        return .asymmetric(
            insertion: travel.animation(.smooth(duration: 0.5).delay(0.05)),
            removal: travel.animation(.smooth(duration: 0.35)))
    }
}

// MARK: - Fecha final

/// Fecha final del Kit: atajos y «Otra fecha». Son dos filas de la sección que la contenga.
struct KitDueDateField: View {
    @Binding var dueDate: Date?
    let todayStart: Date
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsOtherDate = false

    var body: some View {
        dateShortcuts
        if showsOtherDate {
            // Mostrar un día en el selector no lo elige: atenuado hasta que la persona toque uno.
            HStack {
                Text("Elige el día")
                Spacer(minLength: 8)
                DatePicker("Elige el día", selection: Binding(get: { dueDate ?? todayStart }, set: { dueDate = $0 }),
                           in: todayStart..., displayedComponents: .date)
                    .labelsHidden()
                    .opacity(dueDate == nil ? 0.5 : 1)
                    .accessibilityIdentifier("kitCreator.dueDate")
            }
            .transition(.formRow)
        }
    }

    /// Atajos sin nada marcado: la fecha la elige la persona, con un toque si le vale uno de ellos.
    private var dateShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
            layout {
                Label { Text("Fecha final") } icon: { IconChip(symbol: Symbols.calendar, color: MetaTint.date, size: 28) }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                if !showsOtherDate {
                    Text(dueDate?.formatted(.dateTime.day().month(.abbreviated).year()) ?? String(localized: "Sin elegir"))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
            .accessibilityElement(children: .combine)
            // Las chips ocupan todo el ancho: en una fila si caben y, si no, en las que necesite el texto.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    todayChip; tomorrowChip; weekChip; monthChip; threeMonthsChip; otherDateButton
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) { todayChip; tomorrowChip; weekChip }
                    HStack(spacing: 8) { monthChip; threeMonthsChip; otherDateButton }
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) { todayChip; tomorrowChip }
                    HStack(spacing: 8) { weekChip; monthChip }
                    HStack(spacing: 8) { threeMonthsChip; otherDateButton }
                }
                VStack(spacing: 8) {
                    todayChip; tomorrowChip; weekChip; monthChip; threeMonthsChip; otherDateButton
                }
            }
            Text("Es la fecha límite. Puedes terminar antes.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if lateForToday {
                // «Hoy» a última hora caduca a medianoche: se avisa, sin cambiar lo que significa la fecha.
                Text("Queda poco de hoy. Si lo acabarás mañana, elige Mañana.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: lateForToday)
        .onAppear {
            // Una fecha que llega desde el Calendario no coincide con ningún atajo.
            if let dueDate, !isShortcut(dueDate) { showsOtherDate = true }
        }
    }

    private var lateForToday: Bool {
        guard let dueDate, Calendar.current.isDateInToday(dueDate) else { return false }
        return Calendar.current.component(.hour, from: .now) >= 22
    }

    private var todayChip: some View { shortcut(String(localized: "Hoy"), .day, 0).accessibilityIdentifier("kitCreator.today") }
    private var tomorrowChip: some View { shortcut(String(localized: "Mañana"), .day, 1) }
    private var weekChip: some View { shortcut(String(localized: "1 semana"), .day, 7) }
    private var monthChip: some View { shortcut(String(localized: "1 mes"), .month, 1) }
    private var threeMonthsChip: some View { shortcut(String(localized: "3 meses"), .month, 3) }

    private func shortcutDate(_ component: Calendar.Component, _ value: Int) -> Date? {
        Calendar.current.date(byAdding: component, value: value, to: todayStart)
    }

    private func isShortcut(_ date: Date) -> Bool {
        [shortcutDate(.day, 0), shortcutDate(.day, 1), shortcutDate(.day, 7), shortcutDate(.month, 1), shortcutDate(.month, 3)].contains { candidate in
            candidate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
        }
    }

    private func shortcut(_ title: String, _ component: Calendar.Component, _ value: Int) -> some View {
        let date = shortcutDate(component, value)
        let selected = !showsOtherDate && date != nil && dueDate.map { Calendar.current.isDate($0, inSameDayAs: date!) } == true
        return dateChip(title, selected: selected) {
            showsOtherDate = false
            dueDate = date
        }
    }

    private var otherDateButton: some View {
        dateChip(String(localized: "Otra fecha"), selected: showsOtherDate) {
            // Sin fecha hasta que elija una: también si venía de un atajo.
            if !showsOtherDate { dueDate = nil }
            showsOtherDate = true
        }
        .accessibilityIdentifier("kitCreator.otherDate")
        .sensoryFeedback(.selection, trigger: showsOtherDate)
    }

    private func dateChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        DateChip(title: title, selected: selected, action: action)
    }
}

/// Atajo de fecha: el mismo al crear un Kit y al planificar un paso.
struct DateChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let tap = { withAnimation(.formReveal) { action() } }
        // A su tamaño: si el texto no cabe, la fila pasa a otra disposición en vez de cortarlo.
        let label = Text(title).lineLimit(1).fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
        if selected {
            Button(action: tap) { label }.buttonStyle(.borderedProminent).controlSize(.small)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: tap) { label }.buttonStyle(.bordered).controlSize(.small)
        }
    }
}

/// Atajos de fecha de un paso. Solo aparecen los días que el paso puede usar, y solo si hay más de uno.
struct StepDateShortcuts: View {
    let selection: Date?
    let earliest: Date
    let latest: Date?
    let onPick: (Date) -> Void

    private struct Option: Identifiable {
        let id: String
        let title: String
        let day: Date
    }

    private var options: [Option] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let candidates: [(String, String, Calendar.Component, Int)] = [
            ("today", String(localized: "Hoy"), .day, 0),
            ("tomorrow", String(localized: "Mañana"), .day, 1),
            ("week", String(localized: "1 semana"), .day, 7),
            ("month", String(localized: "1 mes"), .month, 1),
            ("quarter", String(localized: "3 meses"), .month, 3)
        ]
        let first = calendar.startOfDay(for: earliest)
        let last = latest.map(calendar.startOfDay(for:))
        return candidates.compactMap { id, title, component, value in
            guard let day = calendar.date(byAdding: component, value: value, to: today),
                  day >= first, last.map({ day <= $0 }) ?? true else { return nil }
            return Option(id: id, title: title, day: day)
        }
    }

    var body: some View {
        let options = options
        // Con un solo día posible no hay nada que elegir.
        if options.count > 1 {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(options) { chip($0) }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach(options) { chip($0) }
                }
                VStack(spacing: 8) {
                    ForEach(options) { chip($0) }
                }
            }
            .transition(.formRow)
        }
    }

    private func chip(_ option: Option) -> some View {
        DateChip(title: option.title,
                 selected: selection.map { Calendar.current.isDate($0, inSameDayAs: option.day) } ?? false) {
            onPick(Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: option.day) ?? option.day)
        }
        .accessibilityIdentifier("stepDate.\(option.id)")
    }
}

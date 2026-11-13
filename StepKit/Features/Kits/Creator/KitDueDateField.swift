//
//  KitDueDateField.swift
//  StepKit
//

import SwiftUI

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

//
//  DecoratedCalendarView.swift
//  StepKit
//
//  UICalendarView del sistema con las decoraciones de v4.4: sesión reservada
//  (punto), paso sugerido (círculo) y fecha prevista (bandera). Un día puede
//  llevar varias a la vez.
//

import SwiftUI
import UIKit

enum CalendarMark: Int, Comparable, CaseIterable {
    case session, suggestion, wantedDate

    static func < (lhs: CalendarMark, rhs: CalendarMark) -> Bool { lhs.rawValue < rhs.rawValue }

    var symbol: String {
        switch self {
        case .session: "circle.fill"
        case .suggestion: "circle"
        case .wantedDate: "flag.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .session, .suggestion: .systemBlue
        case .wantedDate: .systemPurple
        }
    }

    /// Las marcas de un día en fila, en el orden de la leyenda.
    static func decoration(for marks: Set<CalendarMark>) -> UICalendarView.Decoration? {
        guard !marks.isEmpty else { return nil }
        let sorted = marks.sorted()
        return .customView {
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 2
            stack.alignment = .center
            stack.isAccessibilityElement = false
            for mark in sorted {
                let config = UIImage.SymbolConfiguration(pointSize: mark == .wantedDate ? 9 : 7, weight: .bold)
                let image = UIImageView(image: UIImage(systemName: mark.symbol, withConfiguration: config))
                image.tintColor = mark.color
                stack.addArrangedSubview(image)
            }
            return stack
        }
    }
}

struct DecoratedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    /// Marcas de cada día (año, mes, día).
    var marks: [DateComponents: Set<CalendarMark>]
    /// Al cambiar, el calendario muestra el mes del día elegido (botón Hoy).
    var revealToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current
        view.locale = Locale.current
        view.fontDesign = .rounded
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.visibleDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        view.selectionBehavior = selection
        view.setContentHuggingPriority(.required, for: .vertical)
        context.coordinator.lastMarks = marks
        context.coordinator.lastRevealToken = revealToken
        return view
    }

    /// El calendario mide lo que necesita el mes visible (5 o 6 semanas): sin huecos ni cortes.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 360
        let fitted = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitted.height)
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        context.coordinator.parent = self
        let components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        if let selection = view.selectionBehavior as? UICalendarSelectionSingleDate,
           selection.selectedDate != components {
            selection.setSelected(components, animated: true)
        }
        if context.coordinator.lastRevealToken != revealToken {
            context.coordinator.lastRevealToken = revealToken
            view.setVisibleDateComponents(components, animated: true)
        }
        if context.coordinator.lastMarks != marks {
            let changed = Set(context.coordinator.lastMarks.keys).union(marks.keys)
            context.coordinator.lastMarks = marks
            view.reloadDecorations(forDateComponents: Array(changed), animated: true)
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: DecoratedCalendarView
        var lastMarks: [DateComponents: Set<CalendarMark>] = [:]
        var lastRevealToken = 0

        init(_ parent: DecoratedCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            let key = DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day)
            return CalendarMark.decoration(for: parent.marks[key] ?? [])
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
            Task { @MainActor in self.parent.selectedDate = date }
        }
    }
}

extension DateComponents {
    /// Clave de día para las marcas del calendario.
    static func day(of date: Date) -> DateComponents {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: c.year, month: c.month, day: c.day)
    }
}

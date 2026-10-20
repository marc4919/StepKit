//
//  DecoratedCalendarView.swift
//  StepKit
//
//  UICalendarView del sistema con las decoraciones de v4.4: sesión reservada
//  (punto), paso sugerido (círculo) y fecha deseada (bandera).
//

import SwiftUI
import UIKit

enum CalendarMark: Int, Comparable {
    case suggestion, wantedDate, session

    static func < (lhs: CalendarMark, rhs: CalendarMark) -> Bool { lhs.rawValue < rhs.rawValue }

    var decoration: UICalendarView.Decoration {
        switch self {
        case .session: .default(color: .systemBlue, size: .medium)
        case .suggestion: .image(UIImage(systemName: "circle"), color: .systemBlue, size: .small)
        case .wantedDate: .image(UIImage(systemName: "flag.fill"), color: .systemPurple, size: .medium)
        }
    }
}

struct DecoratedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    /// Marca más importante por día (año, mes, día).
    var marks: [DateComponents: CalendarMark]

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
        if let selection = view.selectionBehavior as? UICalendarSelectionSingleDate {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
            if selection.selectedDate != components {
                selection.setSelected(components, animated: true)
            }
        }
        if context.coordinator.lastMarks != marks {
            let changed = Set(context.coordinator.lastMarks.keys).union(marks.keys)
            context.coordinator.lastMarks = marks
            view.reloadDecorations(forDateComponents: Array(changed), animated: true)
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: DecoratedCalendarView
        var lastMarks: [DateComponents: CalendarMark] = [:]

        init(_ parent: DecoratedCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            let key = DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day)
            return parent.marks[key]?.decoration
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

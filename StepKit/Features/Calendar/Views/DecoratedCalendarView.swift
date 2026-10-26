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

    /// Las marcas de un día en fila, en el orden de la leyenda: un punto por cada cosa
    /// (hasta 3 por tipo), para ver de un vistazo cuánto tienes ese día.
    static func decoration(for counts: [CalendarMark: Int]) -> UICalendarView.Decoration? {
        var symbols: [(UIImage, UIColor)] = []
        for mark in CalendarMark.allCases.sorted() {
            let count = counts[mark] ?? 0
            guard count > 0 else { continue }
            let config = UIImage.SymbolConfiguration(pointSize: mark == .wantedDate ? 9 : 6, weight: .bold)
            guard let image = UIImage(systemName: mark.symbol, withConfiguration: config) else { continue }
            for _ in 0..<(mark == .wantedDate ? 1 : min(count, 3)) { symbols.append((image, mark.color)) }
        }
        guard !symbols.isEmpty else { return nil }
        // Se dibujan en una sola imagen: las vistas personalizadas sin tamaño propio no se ven.
        let spacing: CGFloat = 1.5
        let width = symbols.reduce(0) { $0 + $1.0.size.width } + spacing * CGFloat(symbols.count - 1)
        let height = symbols.map(\.0.size.height).max() ?? 8
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in
            var x: CGFloat = 0
            for (image, color) in symbols {
                let tinted = image.withTintColor(color, renderingMode: .alwaysOriginal)
                tinted.draw(at: CGPoint(x: x, y: (height - image.size.height) / 2))
                x += image.size.width + spacing
            }
        }
        return .image(rendered.withRenderingMode(.alwaysOriginal), color: nil, size: .large)
    }
}

struct DecoratedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    /// Marcas de cada día (año, mes, día).
    var marks: [DateComponents: [CalendarMark: Int]]
    /// Al cambiar, el calendario muestra el mes del día elegido (botón Hoy).
    var revealToken: Int = 0
    /// Al cambiar, la lista que contiene el calendario baja hasta lo que hay debajo (el detalle del día).
    var detailToken: Int = 0

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
        if context.coordinator.lastDetailToken != detailToken {
            context.coordinator.lastDetailToken = detailToken
            Self.revealContentBelow(view)
        }
        if context.coordinator.lastMarks != marks {
            let changed = Set(context.coordinator.lastMarks.keys).union(marks.keys)
            context.coordinator.lastMarks = marks
            view.reloadDecorations(forDateComponents: Array(changed), animated: true)
        }
    }

    /// La lista de SwiftUI ignora `scrollTo` mientras el calendario procesa la selección,
    /// así que se desplaza su UIScrollView: el borde inferior del calendario queda arriba.
    private static func revealContentBelow(_ view: UICalendarView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var ancestor = view.superview
            while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
            guard let scrollView = ancestor as? UIScrollView else { return }
            let calendarBottom = view.convert(view.bounds, to: scrollView).maxY
            let top = -scrollView.adjustedContentInset.top
            let maxY = max(top, scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
            let target = min(maxY, max(top, calendarBottom - scrollView.adjustedContentInset.top - 24))
            guard abs(target - scrollView.contentOffset.y) > 1 else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.5, delay: 0,
                           options: [.curveEaseInOut, .allowUserInteraction]) {
                scrollView.contentOffset.y = target
            }
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: DecoratedCalendarView
        var lastMarks: [DateComponents: [CalendarMark: Int]] = [:]
        var lastRevealToken = 0
        var lastDetailToken = 0

        init(_ parent: DecoratedCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            let key = DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day)
            return CalendarMark.decoration(for: parent.marks[key] ?? [:])
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
            // Animado: las filas del día entran y salen con suavidad al cambiar de un día a otro.
            Task { @MainActor in withAnimation(.smooth(duration: 0.35)) { self.parent.selectedDate = date } }
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

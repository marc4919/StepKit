//
//  CalendarUIView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//

import SwiftUI
import UIKit

struct CalendarUIView: UIViewRepresentable {
    @Binding var selectedDate: Date
    var stepsPerDay: [DateComponents: Int]
    var deadlinesPerDay: [DateComponents: Int]
    var accentColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let calendarView = UICalendarView()
        calendarView.delegate = context.coordinator
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale.current
        calendarView.fontDesign = .rounded
        calendarView.tintColor = accentColor
        calendarView.wantsDateDecorations = true
        calendarView.backgroundColor = .clear
        calendarView.translatesAutoresizingMaskIntoConstraints = false

        // Mostrar el mes actual
        let visibleComponents = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        calendarView.visibleDateComponents = visibleComponents

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        calendarView.selectionBehavior = selection

        containerView.addSubview(calendarView)

        // Centrar horizontalmente, con padding vertical
        NSLayoutConstraint.activate([
            calendarView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            calendarView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            calendarView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 16),
            calendarView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            calendarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        context.coordinator.calendarView = calendarView

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self

        guard let calendarView = context.coordinator.calendarView else { return }

        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
            let newComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
            if selection.selectedDate != newComponents {
                selection.selectedDate = newComponents
            }
        }

        // Solo recargar decoraciones si los datos cambiaron
        let stepsChanged = context.coordinator.lastStepsPerDay != stepsPerDay
        let deadlinesChanged = context.coordinator.lastDeadlinesPerDay != deadlinesPerDay

        if stepsChanged || deadlinesChanged {
            // Incluir fechas anteriores Y actuales para recargar (importante para eliminaciones)
            let previousDates = Set(context.coordinator.lastStepsPerDay.keys)
                .union(Set(context.coordinator.lastDeadlinesPerDay.keys))
            let currentDates = Set(stepsPerDay.keys).union(Set(deadlinesPerDay.keys))
            let allDates = Array(previousDates.union(currentDates))

            context.coordinator.lastStepsPerDay = stepsPerDay
            context.coordinator.lastDeadlinesPerDay = deadlinesPerDay

            if !allDates.isEmpty {
                calendarView.reloadDecorations(forDateComponents: allDates, animated: false)
            }
        }
    }

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarUIView
        var calendarView: UICalendarView?
        var lastStepsPerDay: [DateComponents: Int] = [:]
        var lastDeadlinesPerDay: [DateComponents: Int] = [:]

        init(_ parent: CalendarUIView) {
            self.parent = parent
        }

        // MARK: - Selection
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else { return }

            Task { @MainActor in
                self.parent.selectedDate = date
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }

        // MARK: - Decorations
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let year = dateComponents.year,
                  let month = dateComponents.month,
                  let day = dateComponents.day else { return nil }

            let stepsNum = stepsCount(year: year, month: month, day: day)
            let hasDeadline = deadlineCount(year: year, month: month, day: day) > 0

            if stepsNum > 0 && hasDeadline {
                return .customView {
                    self.createCombinedIndicator(stepsCount: stepsNum)
                }
            } else if stepsNum > 0 {
                return .customView {
                    self.createStepsIndicator(count: stepsNum)
                }
            } else if hasDeadline {
                return .customView {
                    self.createDeadlineIndicator()
                }
            }

            return nil
        }

        private func stepsCount(year: Int, month: Int, day: Int) -> Int {
            for (components, count) in parent.stepsPerDay {
                if components.year == year && components.month == month && components.day == day {
                    return count
                }
            }
            return 0
        }

        private func deadlineCount(year: Int, month: Int, day: Int) -> Int {
            for (components, count) in parent.deadlinesPerDay {
                if components.year == year && components.month == month && components.day == day {
                    return count
                }
            }
            return 0
        }

        // Colores de la app (usando UIColor centralizado)
        private var stepColor: UIColor { .uiAccentHighlight }
        private var deadlineColor: UIColor { parent.accentColor }

        // Indicador de steps (puntos azul claro según cantidad)
        private func createStepsIndicator(count: Int) -> UIView {
            let dotsToShow = min(count, 3)
            let dotSize: CGFloat = 5
            let spacing: CGFloat = 3
            let totalWidth = CGFloat(dotsToShow) * dotSize + CGFloat(dotsToShow - 1) * spacing
            let containerHeight: CGFloat = dotSize + 2

            let container = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: containerHeight))
            container.transform = CGAffineTransform(translationX: 0, y: -12)

            var xOffset: CGFloat = 0
            for _ in 0..<dotsToShow {
                let dot = UIView(frame: CGRect(x: xOffset, y: 0, width: dotSize, height: dotSize))
                dot.backgroundColor = stepColor
                dot.layer.cornerRadius = dotSize / 2
                container.addSubview(dot)
                xOffset += dotSize + spacing
            }

            return container
        }

        // Indicador de deadline (punto azul oscuro sólido)
        private func createDeadlineIndicator() -> UIView {
            let size: CGFloat = 6
            let containerHeight: CGFloat = size + 2
            let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: containerHeight))
            container.transform = CGAffineTransform(translationX: 0, y: -8)
            
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            dot.backgroundColor = deadlineColor
            dot.layer.cornerRadius = size / 2
            container.addSubview(dot)
            
            return container
        }

        // Indicador combinado (steps + deadline)
        private func createCombinedIndicator(stepsCount: Int) -> UIView {
            let dotsToShow = min(stepsCount, 2)
            let dotSize: CGFloat = 5
            let ringSize: CGFloat = 7
            let spacing: CGFloat = 3
            let totalWidth = CGFloat(dotsToShow) * dotSize + CGFloat(dotsToShow) * spacing + ringSize
            let containerHeight: CGFloat = ringSize + 2

            let container = UIView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: containerHeight))
            container.transform = CGAffineTransform(translationX: 0, y: -12)

            var xOffset: CGFloat = 0

            // Puntos azul claro
            for _ in 0..<dotsToShow {
                let dot = UIView(frame: CGRect(x: xOffset, y: 0, width: dotSize, height: dotSize))
                dot.backgroundColor = stepColor
                dot.layer.cornerRadius = dotSize / 2
                container.addSubview(dot)
                xOffset += dotSize + spacing
            }

            // Punto azul oscuro sólido - alineado verticalmente con los puntos de pasos
            let deadlineY = (dotSize - ringSize) / 2
            let deadlineDot = UIView(frame: CGRect(x: xOffset, y: deadlineY, width: ringSize, height: ringSize))
            deadlineDot.backgroundColor = deadlineColor
            deadlineDot.layer.cornerRadius = ringSize / 2
            container.addSubview(deadlineDot)

            return container
        }

        private func createDot(color: UIColor, size: CGFloat) -> UIView {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = size / 2
            dot.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: size),
                dot.heightAnchor.constraint(equalToConstant: size)
            ])

            return dot
        }
    }
}

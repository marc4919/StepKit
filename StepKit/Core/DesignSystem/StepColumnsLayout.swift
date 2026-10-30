//
//  StepColumnsLayout.swift
//  StepKit
//
//  Una o dos columnas con los mismos hijos: cambia la disposición, no la identidad de las vistas.
//  Con un `if` entre dos árboles distintos, al girar o plegar el iPhone Duo las vistas se recreaban,
//  y el interruptor de cristal del sistema «materializaba» desde un cuadrado durante un instante.
//

import SwiftUI

struct StepColumnsLayout: Layout {
    var wide: Bool
    /// Índices de los hijos que, en dos columnas, van a la derecha.
    var rightColumn: Set<Int>
    var spacing: CGFloat = 18
    var columnSpacing: CGFloat = 20

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        if wide {
            let columnWidth = max(0, (width - columnSpacing) / 2)
            var heights: [CGFloat] = [0, 0]
            var counts = [0, 0]
            for (index, subview) in subviews.enumerated() {
                let column = rightColumn.contains(index) ? 1 : 0
                let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
                guard height > 0 else { continue }
                heights[column] += height + (counts[column] > 0 ? spacing : 0)
                counts[column] += 1
            }
            return CGSize(width: width, height: max(heights[0], heights[1]))
        }
        var total: CGFloat = 0
        var count = 0
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            guard height > 0 else { continue }
            total += height + (count > 0 ? spacing : 0)
            count += 1
        }
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if wide {
            let columnWidth = max(0, (bounds.width - columnSpacing) / 2)
            var y: [CGFloat] = [bounds.minY, bounds.minY]
            for (index, subview) in subviews.enumerated() {
                let column = rightColumn.contains(index) ? 1 : 0
                let x = bounds.minX + CGFloat(column) * (columnWidth + columnSpacing)
                let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
                subview.place(at: CGPoint(x: x, y: y[column]), anchor: .topLeading,
                              proposal: ProposedViewSize(width: columnWidth, height: size.height))
                if size.height > 0 { y[column] += size.height + spacing }
            }
            return
        }
        var y = bounds.minY
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: size.height))
            if size.height > 0 { y += size.height + spacing }
        }
    }
}

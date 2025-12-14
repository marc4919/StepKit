//
//  CalendarSectionView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI
import UIKit

struct CalendarSectionView: View {
    @Binding var selectedDate: Date
    let stepsPerDay: [DateComponents: Int]
    let deadlinesPerDay: [DateComponents: Int]
    
    var body: some View {
        VStack(spacing: 0) {
            CalendarUIView(
                selectedDate: $selectedDate,
                stepsPerDay: stepsPerDay,
                deadlinesPerDay: deadlinesPerDay,
                accentColor: UIColor.tintColor
            )
            .frame(height: 450)

            // Leyenda sutil
            HStack(spacing: 16) {
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentHighlight)
                        .frame(width: 6, height: 6)
                    Text("Pasos")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                    Text("Deadline")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

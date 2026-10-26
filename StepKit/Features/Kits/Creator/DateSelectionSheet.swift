//
//  DateSelectionSheet.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI
import UIKit

// MARK: - Date Selection Sheet

struct DateSelectionSheet: View {
    @Binding var selectedDate: Date
    let todayStart: Date
    @Environment(\.dismiss) private var dismiss

    @State private var hasManuallySelected = false


    private var baseDate: Date {
        hasManuallySelected ? selectedDate : todayStart
    }

    private var quickDateOptions: [(String, Date)] {
        let calendar = Calendar.current
        return [
            ("Hoy", todayStart),
            ("+1 semana", calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate) ?? baseDate),
            ("+1 mes", calendar.date(byAdding: .month, value: 1, to: baseDate) ?? baseDate)
        ]
    }

    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: todayStart, to: selectedDate).day ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                quickOptionsSection
                    .padding(.top, 8)

                DatePicker("", selection: $selectedDate, in: todayStart..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .onChange(of: selectedDate) { oldValue, newValue in
                        let isFromQuickOption = quickDateOptions.contains { Calendar.current.isDate($0.1, inSameDayAs: newValue) }
                        if !isFromQuickOption {
                            hasManuallySelected = true
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                Spacer(minLength: 0)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(daysRemaining == 0 ? String(localized: "Hoy") : String(localized: "En \(daysRemaining) días"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var quickOptionsSection: some View {
        HStack(spacing: 12) {
            ForEach(quickDateOptions, id: \.0) { option in
                let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: option.1)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = option.1
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(option.0)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [Color.accentHighlight, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    DateSelectionSheet(selectedDate: .constant(Date()), todayStart: Date())
}

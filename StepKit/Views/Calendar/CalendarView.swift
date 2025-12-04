//
//  CalendarView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 2/12/25.
//

import SwiftUI
import SwiftData
import UIKit

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GoalEntity> { !$0.isDeleted },
           sort: \GoalEntity.createdAt,
           order: .reverse)
    private var goalEntities: [GoalEntity]
    
    @State private var selectedDate: Date = Date()
    @State private var showingFastCreator = false
    
    // Colores del tema (consistente con otras vistas)
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    // Kits (Goals) del día seleccionado
    private var goalsForSelectedDate: [GoalEntity] {
        goalEntities.filter { entity in
            guard let dueDate = entity.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Calendario
                        calendarSection
                        
                        // Kits del día seleccionado
                        kitsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .background(Color(.systemGroupedBackground))
                
                // FAB para crear kit
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        fabButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingFastCreator) {
                FastCreatorView(
                    onKitCreated: { _ in
                        // SwiftData + @Query recargan automáticamente
                    },
                    initialDate: selectedDate
                )
            }
        }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 0) {
            DatePicker(
                "Fecha",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(accentBlue)
            .padding(16)
            .onChange(of: selectedDate) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Kits Section
    private var kitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Título de la sección
            HStack {
                Text(selectedDateTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !goalsForSelectedDate.isEmpty {
                    Text("\(goalsForSelectedDate.count) kit\(goalsForSelectedDate.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            if goalsForSelectedDate.isEmpty {
                // Estado vacío
                emptyStateForDay
            } else {
                // Lista de kits
                VStack(spacing: 12) {
                    ForEach(goalsForSelectedDate) { goal in
                        kitRow(goal)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Selected Date Title
    private var selectedDateTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Mañana"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
    }
    
    // MARK: - Empty State
    private var emptyStateForDay: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentHighlight.opacity(0.6), accentBlue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Sin objetivos para este día")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Pulsa + para crear uno")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Kit Row
    private func kitRow(_ goal: GoalEntity) -> some View {
        let progress = goal.computedProgress
        
        return HStack(spacing: 14) {
            // Icono de progreso
            ZStack {
                Circle()
                    .stroke(accentBlue.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [accentHighlight, accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(accentBlue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Fecha objetivo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - FAB Button
    private var fabButton: some View {
        Button {
            showingFastCreator = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [accentHighlight, accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: glowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarView()
}

//
//  FastCreator.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import UIKit

struct FastCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var inconveniences = ""
    @State private var dailyAvailableTime = ""
    @State private var showingDateSheet = false
    @FocusState private var focusDesc: Bool
    @State private var sheetDetent: PresentationDetent = .fraction(0.7)

    
    private var todayStart: Date {
        Calendar.current.startOfDay(for: .now)
    }
    
    private var isDateInPast: Bool {
        dueDate < todayStart
    }
    
    private var isFormValid: Bool {
        !description.isEmpty && !isDateInPast
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo con gradiente sutil para el efecto glass
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        Color.blue.opacity(0.08)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // Contenedor con el formulario
                        VStack(alignment: .leading, spacing: 24) {
                        // Sección de Información Principal
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Información Principal")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Descripción")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $description)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .focused($focusDesc)
                                
                                // Fila compacta de fecha
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fecha objetivo")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Button {
                                        showingDateSheet = true
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        HStack {
                                            Text(dueDate, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                                                .foregroundColor(.primary)
                                            Spacer()
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.blue.opacity(0.1))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14, weight: .medium))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("Fecha objetivo")
                                    .accessibilityValue(dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                                    .accessibilityHint("Toca para cambiar la fecha objetivo")
                                    
                                    // Aviso si la fecha es pasada
                                    if isDateInPast {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Text("La fecha seleccionada ya ha pasado")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        
                        // Sección de información adicional
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Información Adicional")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Explica tus inconvenientes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextField("Describe cualquier inconveniente...", text: $inconveniences, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tiempo disponible diario")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextField("Ej: 2 horas, 30 minutos...", text: $dailyAvailableTime)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        // Botón de guardar dentro del contenedor
                        Button("Guardar objetivo") {
                            // Acción de guardar
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isFormValid)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .padding(.horizontal, 16)
                        
                        Spacer()
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Nuevo Objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack) // Mejor para iPhone, evita split view
        .sheet(isPresented: $showingDateSheet) {
            DateSelectionSheet(selectedDate: $dueDate, todayStart: todayStart)
                .presentationDetents(Set([.fraction(0.7), .large]), selection: $sheetDetent)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Date Selection Sheet
struct DateSelectionSheet: View {
    @Binding var selectedDate: Date
    let todayStart: Date
    @Environment(\.dismiss) private var dismiss
    
    private var quickDateOptions: [(String, Date)] {
        let calendar = Calendar.current
        let today = todayStart
        
        return [
            ("Hoy", today),
            ("+1 semana", calendar.date(byAdding: .weekOfYear, value: 1, to: today) ?? today),
            ("Fin de mes", calendar.dateInterval(of: .month, for: today)?.end.addingTimeInterval(-86400) ?? today),
            ("+30 días", calendar.date(byAdding: .day, value: 30, to: today) ?? today)
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chips de acciones rápidas
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(quickDateOptions, id: \.0) { option in
                            Button(option.0) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedDate = option.1
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .frame(minHeight: 44) // Target de toque mínimo
                            .disabled(Calendar.current.isDate(selectedDate, inSameDayAs: option.1))
                            .accessibilityLabel("Seleccionar \(option.0)")
                            .accessibilityHint("Establece la fecha objetivo a \(option.0)")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Calendario gráfico
                DatePicker("", selection: $selectedDate, in: todayStart..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.accentColor)
                    .padding()
                    .environment(\.accessibilityEnabled, true)
                    .accessibilityLabel("Selecciona una fecha")
                    .accessibilityHint("Desliza para cambiar el mes o toca una fecha para seleccionarla")
                    .onChange(of: selectedDate) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                
                Spacer(minLength: 0)
            }
            .navigationTitle("Seleccionar Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                // Botón de confirmación sin separador ni fondo distinto
                Button("Confirmar") {
                    dismiss()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }
}

#Preview {
    FastCreatorView()
}

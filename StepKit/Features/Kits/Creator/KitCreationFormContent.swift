//
//  KitCreationFormContent.swift
//  StepKit
//
//  Extracted from KitCreatorView.swift
//

import SwiftUI

struct KitCreationFormContent: View {
    @Binding var description: String
    @Binding var dueDate: Date
    @Binding var inconveniences: String
    @Binding var dailyAvailableTime: String
    @Binding var showingDateSheet: Bool
    
    var focusedField: FocusState<KitCreatorField?>.Binding
    let todayStart: Date
    let isDateInPast: Bool
    let isFormValid: Bool
    let onCreate: () -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    
                    // Main Info Section
                    KitCreatorSection(icon: "doc.text", title: "Información Principal") {
                        KitCreatorTextField(
                            title: "¿Qué quieres conseguir?",
                            placeholder: "Ej: Aprender a tocar guitarra, correr una maratón...",
                            text: $description,
                            focusBinding: focusedField,
                            fieldType: .description
                        )
                        
                        KitCreatorDateRow(
                            date: $dueDate,
                            isDateInPast: isDateInPast,
                            onTap: {
                                focusedField.wrappedValue = nil
                                showingDateSheet = true
                            }
                        )
                    }
                    
                    // Additional Info Section
                    KitCreatorSection(icon: "lightbulb", title: "Información Adicional") {
                        Text("Opcional pero nos ayuda a personalizar tu plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, -8)
                        
                        KitCreatorTextField(
                            title: "Tiempo disponible",
                            placeholder: "Ej: 2 horas / semana, 30 min al día, solo fines de semana…",
                            text: $dailyAvailableTime,
                            focusBinding: focusedField,
                            fieldType: .time
                        )
                        
                        KitCreatorTextField(
                            title: "¿Qué obstáculos anticipas?",
                            placeholder: "Ej: Poco tiempo, falta de experiencia...",
                            text: $inconveniences,
                            focusBinding: focusedField,
                            fieldType: .obstacles
                        )
                    }
                    
                    saveButton
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .onChange(of: focusedField.wrappedValue) { _, field in
                guard let field = field else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    switch field {
                    case .description:
                        proxy.scrollTo("descriptionField", anchor: .center)
                    case .obstacles:
                        proxy.scrollTo("obstaclesField", anchor: .center)
                    case .time:
                        proxy.scrollTo("timeField", anchor: .center)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.3))
                    .frame(width: 56, height: 56)

                Image(systemName: "target")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(LinearGradient.accentGradient)
                    .symbolEffect(.variableColor.cumulative.dimInactiveLayers.nonReversing, options: .nonRepeating)
            }

            Text("Define tu objetivo")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Solo necesitamos algunos detalles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCreate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                Text("Crear Kit")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isFormValid
                    ? LinearGradient.accentGradient
                    : LinearGradient.disabledGradient
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isFormValid ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid)
        .accessibilityIdentifier("kitCreator.create")
        .padding(.top, 8)
    }
}

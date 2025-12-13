//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData

struct StepDetailView: View {
    @Bindable var stepEntity: StepEntity
    var stepNumber: Int = 1
    @State private var buttonScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncManager) private var syncManager

    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Metadatos (tiempo, fecha, esfuerzo)
                detailsCard

                // Descripción
                if !stepEntity.descriptionLong.isEmpty {
                    descriptionCard
                }

                // Adaptación
                if !stepEntity.adaptsTo.isEmpty {
                    adaptationCard
                }

                // Premium
                if stepEntity.blockedByPremium {
                    premiumCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            bottomAction
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            heroHeader
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        toggleStepNotification()
                    }
                } label: {
                    Image(systemName: stepEntity.notificationEnabled ? "bell.fill" : "bell.slash")
                        .foregroundColor(stepEntity.notificationEnabled ? .accentColor : .secondary)
                        .symbolEffect(.bounce, value: stepEntity.notificationEnabled)
                }
            }
        }
    }

    // MARK: - Step Notification Toggle
    private func toggleStepNotification() {
        stepEntity.notificationEnabled.toggle()
        stepEntity.markModified()

        if stepEntity.notificationEnabled {
            Task {
                await NotificationService.shared.scheduleNotification(for: stepEntity)
            }
        } else {
            NotificationService.shared.cancelNotification(for: stepEntity.id)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error al guardar notificación del step: \(error)")
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Número de paso
            Text("Paso \(stepNumber)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)

            // Título del step
            Text(stepEntity.stepTitle)
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(.primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Description Card
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)

                Text("Descripción")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Descripción corta en negrita
                Text(stepEntity.descriptionShort)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Descripción larga dividida en párrafos
                ForEach(Array(formattedParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Divide el texto en párrafos basándose en oraciones largas (>80 chars que terminan en punto)
    private var formattedParagraphs: [String] {
        let text = stepEntity.descriptionLong
        let threshold = 80

        // Dividir por oraciones (punto seguido de espacio o fin)
        let sentences = text.components(separatedBy: ". ")

        var paragraphs: [String] = []
        var currentParagraph = ""

        for (index, sentence) in sentences.enumerated() {
            let sentenceWithPeriod = index < sentences.count - 1 ? sentence + "." : sentence

            if currentParagraph.isEmpty {
                currentParagraph = sentenceWithPeriod
            } else {
                currentParagraph += " " + sentenceWithPeriod
            }

            // Si el párrafo actual supera el umbral, guardarlo y empezar uno nuevo
            if currentParagraph.count >= threshold {
                paragraphs.append(currentParagraph)
                currentParagraph = ""
            }
        }

        // Añadir el último párrafo si queda algo
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }

        // Si no se dividió en párrafos, devolver el texto original
        return paragraphs.isEmpty ? [text] : paragraphs
    }
    
    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(spacing: 0) {
            // Tiempo estimado
            detailRow(
                icon: "clock.fill",
                iconColor: .accentColor,
                title: "Tiempo estimado",
                value: formatMinutes(stepEntity.estimateMinutes),
                showDivider: true
            )
            
            // Fecha sugerida
            if let deadline = stepEntity.suggestedDeadline {
                detailRow(
                    icon: "calendar",
                    iconColor: .purple,
                    title: "Fecha sugerida",
                    value: deadline.formatted(.dateTime.day().month(.wide)),
                    showDivider: true
                )
            }
            
            // Nivel de esfuerzo
            detailRow(
                icon: effortIcon,
                iconColor: effortColor,
                title: "Nivel de esfuerzo",
                value: effortLevelText,
                showDivider: false,
                trailing: {
                    AnyView(effortIndicator)
                }
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func detailRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        showDivider: Bool,
        trailing: (() -> AnyView)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let trailing = trailing {
                    trailing()
                } else {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }
    
    private var effortIndicator: some View {
        HStack(spacing: 4) {
            Text(effortLevelText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(effortColor)
            
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < effortLevelIndex ? effortColor : Color(.systemGray4))
                        .frame(width: 6, height: 14 - CGFloat(index) * 2)
                }
            }
        }
    }
    
    // MARK: - Adaptation Card
    private var adaptationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Adaptado para ti")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(stepEntity.adaptsTo)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Premium Card
    private var premiumCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 1, green: 0.65, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contenido Premium")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Requiere StepKit Pro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    // Navegar a suscripción
                } label: {
                    Text("Desbloquear")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LinearGradient.accentGradient)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Bottom Action
    private var bottomAction: some View {
        Button {
            let wasCompleted = stepEntity.isCompleted

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: wasCompleted ? .light : .medium)
            generator.impactOccurred()

            // Animación de rebote del botón
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                buttonScale = 0.92
                iconRotation += wasCompleted ? -360 : 360
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    buttonScale = 1.0
                }
            }

            toggleStepCompletion()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: stepEntity.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .rotationEffect(.degrees(iconRotation))

                Text(stepEntity.isCompleted ? "Marcar como pendiente" : "Marcar como completado")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                stepEntity.isCompleted
                    ? LinearGradient.disabledGradient
                    : LinearGradient.accentGradient
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .scaleEffect(buttonScale)
        .animation(.easeInOut(duration: 0.2), value: stepEntity.isCompleted)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Helpers
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    private var effortLevelText: String {
        switch stepEntity.effortLevel.lowercased() {
        case "low": return "Bajo"
        case "medium": return "Medio"
        case "high": return "Alto"
        default: return stepEntity.effortLevel.capitalized
        }
    }
    
    private var effortLevelIndex: Int {
        switch stepEntity.effortLevel.lowercased() {
        case "low": return 1
        case "medium": return 2
        case "high": return 3
        default: return 1
        }
    }
    
    private var effortColor: Color {
        switch stepEntity.effortLevel.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .accentColor
        }
    }
    
    private var effortIcon: String {
        switch stepEntity.effortLevel.lowercased() {
        case "low": return "leaf.fill"
        case "medium": return "flame.fill"
        case "high": return "bolt.fill"
        default: return "gauge"
        }
    }

    // MARK: - Actions

    private func toggleStepCompletion() {
        // Actualizar el StepEntity directamente
        stepEntity.isCompleted.toggle()
        stepEntity.markModified()  // También marca el goal parent

        // Actualizar progreso del goal
        if let goalEntity = stepEntity.goal {
            goalEntity.progress = goalEntity.computedProgress
            goalEntity.markModified()
        }

        // Guardar cambios
        do {
            try modelContext.save()

            // Trigger sync después de cambio
            syncManager?.handleDataChange()
        } catch {
            print("Error al guardar step: \(error)")
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview("Pendiente") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso pendiente",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso",
        estimateMinutes: 45,
        suggestedDeadline: Date(),
        effortLevel: "medium",
        adaptsTo: "Se adapta a tu disponibilidad",
        isCompleted: false
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 1)
    }
    .modelContainer(container)
}

#Preview("Completado") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GoalEntity.self, StepEntity.self, configurations: config)
    let stepEntity = StepEntity(
        stepTitle: "Paso completado",
        descriptionShort: "Descripción corta",
        descriptionLong: "Descripción larga del paso completado",
        estimateMinutes: 30,
        suggestedDeadline: Date(),
        effortLevel: "low",
        adaptsTo: "",
        isCompleted: true
    )
    container.mainContext.insert(stepEntity)

    return NavigationStack {
        StepDetailView(stepEntity: stepEntity, stepNumber: 3)
    }
    .modelContainer(container)
}

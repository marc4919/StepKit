//
//  FastCreatorView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit

struct FastCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient: any APIClientProtocol
    @Environment(\.syncManager) private var syncManager
    @Environment(AuthManager.self) private var authManager

    // Callback cuando se crea un kit exitosamente
    var onKitCreated: ((Goal) -> Void)?

    // Fecha inicial opcional (para cuando se abre desde el calendario)
    var initialDate: Date?

    // MARK: - View State

    private enum ViewState {
        case form
        case loading
        case streaming
    }

    @State private var viewState: ViewState = .form

    // MARK: - Form State

    @State private var description = ""
    @State private var dueDate = Date()
    @State private var inconveniences = ""
    @State private var dailyAvailableTime = ""
    @State private var showingDateSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @FocusState private var focusedField: Field?
    @State private var sheetDetent: PresentationDetent = .fraction(0.7)

    // MARK: - Streaming State

    @State private var streamingState = KitStreamingState()
    @State private var streamingTask: Task<Void, Never>?
    @State private var isCancelled = false

    private enum Field: Hashable {
        case description, obstacles, time
    }


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
        NavigationStack {
            Group {
                switch viewState {
                case .form:
                    formContent
                case .loading:
                    KitCreationLoadingView()
                case .streaming:
                    streamingContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(toolbarTitle)
                        .font(.headline)
                }

                ToolbarItem(placement: .cancellationAction) {
                    if showsCancelButton {
                        Button(cancelButtonTitle) {
                            cancelAndDismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDateSheet) {
            DateSelectionSheet(selectedDate: $dueDate, todayStart: todayStart)
                .presentationDetents(Set([.fraction(0.7), .large]), selection: $sheetDetent)
                .presentationDragIndicator(.visible)
        }
        .alert("Error", isPresented: $showingError) {
            Button("Reintentar") {
                createKit()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Ha ocurrido un error inesperado")
        }
        .interactiveDismissDisabled(viewState != .form)
        .onAppear {
            if let initialDate = initialDate {
                dueDate = initialDate
            }
        }
    }

    // MARK: - Toolbar Helpers

    private var toolbarTitle: String {
        switch viewState {
        case .form: return "Nuevo Kit"
        case .loading, .streaming: return "Creando tu Kit"
        }
    }

    private var showsCancelButton: Bool {
        switch viewState {
        case .form:
            return true
        case .loading:
            return true
        case .streaming:
            return !streamingState.isComplete
        }
    }

    private var cancelButtonTitle: String {
        viewState == .form ? "Cerrar" : "Cancelar"
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    mainInfoSection
                    additionalInfoSection
                    saveButton
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .onChange(of: focusedField) { _, field in
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

    // MARK: - Streaming Content

    private var streamingContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Header con progreso
                    streamingHeaderSection

                    // Título del kit
                    if let title = streamingState.kitTitle {
                        kitTitleSection(title: title)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                    }

                    // Lista de pasos
                    if !streamingState.steps.isEmpty {
                        stepsSection
                    }

                    // Indicador de siguiente paso
                    if !streamingState.isComplete && streamingState.kitTitle != nil {
                        loadingNextStep
                            .id("loading")
                    }

                    // Botones de acción cuando completa
                    if streamingState.isComplete {
                        completedSection
                            .transition(.opacity.combined(with: .scale))
                    }

                    // Error
                    if streamingState.hasError {
                        errorSection
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .onChange(of: streamingState.steps.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("loading", anchor: .bottom)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Streaming Header

    private var streamingHeaderSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: streamingState.progress)
                    .stroke(
                        LinearGradient.accentGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: streamingState.progress)

                if streamingState.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                        .symbolEffect(.variableColor.cumulative, options: .repeating)
                }
            }

            Text(streamingState.statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: streamingState.statusText)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Kit Title Section

    private func kitTitleSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if let kpi = streamingState.kpi {
                Text(kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let days = streamingState.horizonDays {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("\(days) días")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.accentColor)

                Text("Pasos")
                    .font(.headline)

                Spacer()

                if let total = streamingState.totalSteps {
                    Text("\(streamingState.steps.count) de \(total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 12) {
                ForEach(Array(streamingState.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(step: step, index: index)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                        .id("step-\(index)")
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streamingState.steps.count)
    }

    // MARK: - Step Row

    private func stepRow(step: StreamStepOutput, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.3))
                    .frame(width: 32, height: 32)

                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.stepTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(step.description.short)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(step.estimateMinutes) min", systemImage: "clock")
                    Label(formatDeadline(step.suggestedDeadline), systemImage: "calendar")
                    Label(step.effortLevel, systemImage: "flame")
                }
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    private func formatDeadline(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Loading Next Step

    private var loadingNextStep: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.accentColor)

            Text("Generando siguiente paso...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(spacing: 12) {
            Button {
                saveAndNavigate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Ver mi Kit")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.accentGradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .glowShadow(opacity: 0.3, radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                cancelAndDismiss()
            } label: {
                Text("Descartar kit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(streamingState.error ?? "Ha ocurrido un error")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                cancelAndDismiss()
            } label: {
                Text("Volver")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Form Sections

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
                .foregroundColor(.primary)

            Text("Solo necesitamos algunos detalles")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var mainInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "doc.text", title: "Información Principal")

            VStack(alignment: .leading, spacing: 20) {
                // Descripción
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Qué quieres conseguir?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    TextField("Ej: Aprender a tocar guitarra, correr una maratón...", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(focusedField == .description ? Color.accentColor : Color(.separator), lineWidth: focusedField == .description ? 2 : 0.5)
                        )
                        .focused($focusedField, equals: .description)
                        .id("descriptionField")
                }

                // Fecha objetivo
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fecha objetivo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Button {
                        focusedField = nil
                        showingDateSheet = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient.accentWithOpacity( 0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "calendar")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dueDate, format: .dateTime.weekday(.wide))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(dueDate, format: .dateTime.day().month(.wide).year())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fecha objetivo")
                    .accessibilityValue(dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .accessibilityHint("Toca para cambiar la fecha objetivo")

                    if isDateInPast {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("La fecha seleccionada ya ha pasado")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "lightbulb", title: "Información Adicional")

            Text("Opcional pero nos ayuda a personalizar tu plan")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -8)

            VStack(alignment: .leading, spacing: 20) {
                // Tiempo disponible
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiempo disponible")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    TextField("Ej: 2 horas / semana, 30 min al día, solo fines de semana…", text: $dailyAvailableTime, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(focusedField == .time ? Color.accentColor : Color(.separator), lineWidth: focusedField == .time ? 2 : 0.5)
                        )
                        .focused($focusedField, equals: .time)
                        .id("timeField")
                }

                // Obstáculos
                VStack(alignment: .leading, spacing: 8) {
                    Text("¿Qué obstáculos anticipas?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    TextField("Ej: Poco tiempo, falta de experiencia...", text: $inconveniences, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(focusedField == .obstacles ? Color.accentColor : Color(.separator), lineWidth: focusedField == .obstacles ? 2 : 0.5)
                        )
                        .focused($focusedField, equals: .obstacles)
                        .id("obstaclesField")
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            createKit()
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
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isFormValid ? Color.accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Actions

    private func cancelAndDismiss() {
        // Marcar como cancelado
        isCancelled = true

        // Cancelar la tarea de streaming si existe
        streamingTask?.cancel()
        streamingTask = nil

        // Manejar el kit que puede haberse creado en el servidor
        if let kitId = streamingState.kitId {
            // Caso 1: Ya tenemos el kitId (el servidor completó) - eliminar directamente
            deleteKitById(kitId)
        } else if viewState == .streaming || viewState == .loading {
            // Caso 2: No tenemos kitId pero estábamos en proceso
            // El servidor puede crear el kit - marcar sesión como cancelada
            markSessionAsCancelled()
        }

        // Si estamos en form, cerrar. Si no, volver al form.
        if viewState == .form {
            dismiss()
        } else {
            // Volver al formulario desde loading o streaming (sin animación para evitar parpadeo)
            viewState = .form
            streamingState.reset()
        }
    }

    /// Elimina un kit por su ID creando una entidad local marcada como eliminada
    private func deleteKitById(_ kitId: UUID) {
        let now = Date()
        let deletedKit = GoalEntity(
            id: kitId,
            planTitle: streamingState.kitTitle ?? "Cancelled",
            horizonDays: streamingState.horizonDays ?? 0,
            kpi: streamingState.kpi ?? "",
            metaType: "cancelled",
            metaTags: [],
            risks: streamingState.risks,
            version: 2, // Version > 1 para que el sync lo acepte
            progress: 0,
            sourceModel: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: now,
            isDeleted: true
        )
        modelContext.insert(deletedKit)

        do {
            try modelContext.save()
            #if DEBUG
            print("🗑️ Kit \(kitId) marked as deleted locally (cancelled by user)")
            #endif
            // Trigger sync para propagar el delete al servidor
            syncManager?.handleDataChange()
        } catch {
            #if DEBUG
            print("❌ Error saving deleted kit: \(error)")
            #endif
        }
    }

    /// Marca la sesión de creación como cancelada para que el sync elimine kits huérfanos
    private func markSessionAsCancelled() {
        let cancelledAt = Date()
        UserDefaults.standard.set(cancelledAt, forKey: "lastCancelledKitCreationAt")
        #if DEBUG
        print("⚠️ Kit creation session marked as cancelled at \(cancelledAt)")
        #endif
    }

    private func saveAndNavigate() {
        guard let kitDTO = streamingState.kit else { return }

        // Guardar en SwiftData
        let goalEntity = GoalEntity(from: kitDTO)
        modelContext.insert(goalEntity)

        // Añadir los steps
        if let steps = kitDTO.steps {
            for stepDTO in steps {
                let stepEntity = StepEntity(from: stepDTO, goal: goalEntity)
                modelContext.insert(stepEntity)
                goalEntity.steps.append(stepEntity)
            }
        }

        // Guardar
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Kit guardado con \(goalEntity.steps.count) pasos")
            #endif

            // Trigger sync después de crear
            syncManager?.handleDataChange()
        } catch {
            #if DEBUG
            print("❌ Error al guardar en SwiftData: \(error)")
            #endif
        }

        // Callback y cerrar
        let goal = goalEntity.toGoal()
        onKitCreated?(goal)
        dismiss()
    }

    // MARK: - Kit Creation (Streaming)

    private func createKit() {
        guard let token = authManager.token else {
            errorMessage = "Necesitas iniciar sesión para crear un kit"
            showingError = true
            return
        }

        // Cambiar a estado loading
        withAnimation(.easeInOut(duration: 0.3)) {
            viewState = .loading
        }
        errorMessage = nil

        let dailyMinutes = parseMinutes(from: dailyAvailableTime)
        let obstacles = inconveniences
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        streamingState.reset()
        isCancelled = false

        streamingTask = Task {
            // 1. Analizar complejidad
            let complexityResult = await ComplexityRouter.shared.analyzeComplexity(
                goal: description,
                dueDate: dueDate,
                obstacles: obstacles
            )
            
            // Verificar si fue cancelado
            if Task.isCancelled || isCancelled {
                return
            }

            // 2. Crear request
            let request = AIGenerateKitRequest(
                description: description,
                dueDate: dueDate,
                dailyMinutes: dailyMinutes,
                obstacles: obstacles,
                useHeavyweight: complexityResult.useHeavyweight
            )

            #if DEBUG
            print("📤 Enviando request con promptVersion: \(request.promptVersion)")
            #endif

            // 3. Consumir stream
            let stream = apiClient.streamKitGeneration(from: request, token: token)
            var hasReceivedFirstEvent = false

            do {
                for try await event in stream {
                    // Verificar si fue cancelado antes de procesar el evento
                    if Task.isCancelled || isCancelled {
                        return
                    }
                    
                    await MainActor.run {
                        // No actualizar el estado si fue cancelado
                        if isCancelled {
                            return
                        }
                        
                        // Transicionar a streaming cuando llega el primer evento real
                        if !hasReceivedFirstEvent && event.eventType == .kitInfo {
                            hasReceivedFirstEvent = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewState = .streaming
                            }
                        }

                        streamingState.handleEvent(event)
                    }

                    if event.eventType == .error {
                        await MainActor.run {
                            // No actualizar el estado si fue cancelado
                            if isCancelled {
                                return
                            }
                            
                            if !hasReceivedFirstEvent {
                                withAnimation {
                                    viewState = .form
                                }
                                errorMessage = event.error ?? "Error al conectar con la IA"
                                showingError = true
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }

                    if event.eventType == .done {
                        await MainActor.run {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    // No actualizar el estado si fue cancelado
                    if isCancelled {
                        return
                    }
                    
                    if !hasReceivedFirstEvent {
                        withAnimation {
                            viewState = .form
                        }
                        handleError(error)
                    } else {
                        streamingState.setError(mapErrorMessage(error))
                    }
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = mapErrorMessage(error)
        showingError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func mapErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .premiumRequired:
                return "La creación de kits con IA requiere una suscripción premium"
            case .quotaExceeded:
                return "Has alcanzado el límite de creación de kits este mes"
            case .notAuthenticated:
                return "Tu sesión ha expirado. Por favor, vuelve a iniciar sesión"
            case .serverError(let code, _):
                if code >= 500 {
                    return "El servidor no está disponible. Inténtalo más tarde"
                }
                return "No se pudo crear el kit. Inténtalo de nuevo"
            default:
                return apiError.localizedDescription
            }
        } else if (error as NSError).domain == NSURLErrorDomain {
            return "No hay conexión a internet. Verifica tu conexión e inténtalo de nuevo"
        }
        return "No se pudo crear el kit. Inténtalo de nuevo"
    }

    private func parseMinutes(from text: String) -> Int {
        let lowercased = text.lowercased()

        let numberPattern = /(\d+)/
        guard let match = lowercased.firstMatch(of: numberPattern),
              let number = Int(match.1) else {
            return 60
        }

        if lowercased.contains("hora") || lowercased.contains("hour") || lowercased.contains("h ") || lowercased.hasSuffix("h") {
            return number * 60
        }

        if number < 10 {
            return number * 60
        }

        return number
    }
}

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

                        Text(daysRemaining == 0 ? "Hoy" : "En \(daysRemaining) días")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    FastCreatorView()
        .environment(AuthManager())
        .environment(\.apiClient, MockAPIClient())
        .modelContainer(for: [GoalEntity.self, StepEntity.self], inMemory: true)
}

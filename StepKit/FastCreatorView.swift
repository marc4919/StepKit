//
//  FastCreator.swift
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
    @Environment(AuthManager.self) private var authManager
    
    // Callback cuando se crea un kit exitosamente
    var onKitCreated: ((Goal) -> Void)?
    
    // Fecha inicial opcional (para cuando se abre desde el calendario)
    var initialDate: Date?
    
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var inconveniences = ""
    @State private var dailyAvailableTime = ""
    @State private var showingDateSheet = false
    @State private var isCreatingKit = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @FocusState private var focusedField: Field?
    @State private var sheetDetent: PresentationDetent = .fraction(0.7)
    
    private enum Field: Hashable {
        case description, obstacles, time
    }
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    
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
        Group {
            if isCreatingKit {
                // Vista de carga (fuera del NavigationView para evitar conflictos)
                KitCreationLoadingView()
            } else {
                // Formulario
                NavigationStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                headerSection
                                mainInfoSection
                                additionalInfoSection
                                saveButton
                            }
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
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
            }
        }
        .interactiveDismissDisabled(isCreatingKit)
        .onAppear {
            // Si se proporciona una fecha inicial, usarla
            if let initialDate = initialDate {
                dueDate = initialDate
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentHighlight.opacity(0.3), accentBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "target")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentHighlight, accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
    
    // MARK: - Main Info Section
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
                                .stroke(focusedField == .description ? accentBlue : Color(.separator), lineWidth: focusedField == .description ? 2 : 0.5)
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
                        focusedField = nil // Quitar focus para que no vuelva el teclado al cerrar
                        showingDateSheet = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [accentHighlight.opacity(0.2), accentBlue.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "calendar")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(accentBlue)
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
    
    // MARK: - Additional Info Section
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(icon: "lightbulb", title: "Información Adicional")
            
            Text("Opcional pero nos ayuda a personalizar tu plan")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, -8)
            
            VStack(alignment: .leading, spacing: 20) {
                // Tiempo disponible (primero: el usuario reserva tiempo)
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
                                .stroke(focusedField == .time ? accentBlue : Color(.separator), lineWidth: focusedField == .time ? 2 : 0.5)
                        )
                        .focused($focusedField, equals: .time)
                        .id("timeField")
                }
                
                // Obstáculos (después: identifica riesgos)
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
                                .stroke(focusedField == .obstacles ? accentBlue : Color(.separator), lineWidth: focusedField == .obstacles ? 2 : 0.5)
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
    
    // MARK: - Save Button
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
                LinearGradient(
                    colors: isFormValid ? [accentHighlight, accentBlue] : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: isFormValid ? accentBlue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid)
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(accentBlue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Kit Creation
    
    private func createKit() {
        // Verificar autenticación
        guard let token = authManager.token else {
            errorMessage = "Necesitas iniciar sesión para crear un kit"
            showingError = true
            return
        }
        
        // Mostrar vista de carga
        isCreatingKit = true
        errorMessage = nil
        
        // Parsear tiempo disponible (intentar extraer minutos del texto)
        let dailyMinutes = parseMinutes(from: dailyAvailableTime)
        
        // Parsear obstáculos (separar por comas o saltos de línea)
        let obstacles = inconveniences
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Crear el request
        let request = AIGenerateKitRequest(
            description: description,
            dueDate: dueDate,
            dailyMinutes: dailyMinutes,
            obstacles: obstacles
        )
        
        Task {
            do {
                let response = try await apiClient.generateKit(from: request, token: token)
                
                await MainActor.run {
                    handleKitCreationSuccess(response: response)
                }
            } catch {
                await MainActor.run {
                    handleKitCreationError(error)
                }
            }
        }
    }
    
    private func handleKitCreationSuccess(response: AIGenerateKitResponse) {
        guard let kitDTO = response.kit else {
            errorMessage = "El servidor no devolvió un kit válido"
            showingError = true
            isCreatingKit = false
            return
        }
        
        // Guardar en SwiftData
        let goalEntity = GoalEntity(from: kitDTO)
        modelContext.insert(goalEntity)
        
        // Añadir los steps (primero crear todos, luego asociarlos)
        if let stepDTOs = kitDTO.steps {
            for (index, stepDTO) in stepDTOs.enumerated() {
                let stepEntity = StepEntity(from: stepDTO, goal: goalEntity)
                // Asegurar el orden correcto
                stepEntity.order = index
                // Insertar en el contexto
                modelContext.insert(stepEntity)
                // Establecer la relación bidireccional
                goalEntity.steps.append(stepEntity)
            }
        }
        
        // Intentar guardar
        do {
            try modelContext.save()
            print("✅ Kit guardado con \(goalEntity.steps.count) pasos")
        } catch {
            print("❌ Error al guardar en SwiftData: \(error)")
        }
        
        // Convertir desde la entidad guardada (no desde el DTO)
        let goal = goalEntity.toGoal()
        
        // Notificar éxito
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isCreatingKit = false
        
        // Llamar al callback si existe
        onKitCreated?(goal)
        
        // Cerrar la vista
        dismiss()
    }
    
    private func handleKitCreationError(_ error: Error) {
        isCreatingKit = false
        
        // Mapear errores a mensajes amigables
        if let apiError = error as? APIError {
            switch apiError {
            case .premiumRequired:
                errorMessage = "La creación de kits con IA requiere una suscripción premium"
            case .quotaExceeded:
                errorMessage = "Has alcanzado el límite de creación de kits este mes"
            case .notAuthenticated:
                errorMessage = "Tu sesión ha expirado. Por favor, vuelve a iniciar sesión"
            case .serverError(let code, _):
                if code >= 500 {
                    errorMessage = "El servidor no está disponible. Inténtalo más tarde"
                } else {
                    errorMessage = "No se pudo crear el kit. Inténtalo de nuevo"
                }
            default:
                errorMessage = apiError.localizedDescription
            }
        } else if (error as NSError).domain == NSURLErrorDomain {
            errorMessage = "No hay conexión a internet. Verifica tu conexión e inténtalo de nuevo"
        } else {
            errorMessage = "No se pudo crear el kit. Inténtalo de nuevo"
        }
        
        showingError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    /// Intenta extraer minutos de un texto libre como "2 horas" o "30 min"
    private func parseMinutes(from text: String) -> Int {
        let lowercased = text.lowercased()
        
        // Buscar números en el texto
        let numberPattern = /(\d+)/
        guard let match = lowercased.firstMatch(of: numberPattern),
              let number = Int(match.1) else {
            return 60 // Default: 1 hora
        }
        
        // Detectar si son horas
        if lowercased.contains("hora") || lowercased.contains("hour") || lowercased.contains("h ") || lowercased.hasSuffix("h") {
            return number * 60
        }
        
        // Si el número es pequeño (< 10), probablemente son horas
        if number < 10 {
            return number * 60
        }
        
        // De lo contrario, asumir minutos
        return number
    }
}

// MARK: - Date Selection Sheet
struct DateSelectionSheet: View {
    @Binding var selectedDate: Date
    let todayStart: Date
    @Environment(\.dismiss) private var dismiss
    
    // Trackea si el usuario ya interactuó con el calendario
    @State private var hasManuallySelected = false
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    
    // Fecha base: si ya seleccionó manualmente, usa esa fecha; si no, usa hoy
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
    
    // Días restantes hasta la fecha seleccionada
    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: todayStart, to: selectedDate).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Chips de acciones rápidas
                quickOptionsSection
                    .padding(.top, 8)
                
                // Calendario gráfico
                DatePicker("", selection: $selectedDate, in: todayStart..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(accentBlue)
                    .padding(.horizontal)
                    .onChange(of: selectedDate) { oldValue, newValue in
                        // Solo marca como manual si el cambio viene del calendario, no de los botones rápidos
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
    
    // MARK: - Quick Options
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
                                ? AnyShapeStyle(LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
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

//
//  FastCreatorViewModel.swift
//  StepKit
//
//  Created by Assistant on 14/12/25.
//

import SwiftUI
import SwiftData
import FoundationModels
import UIKit

@Observable
@MainActor
final class FastCreatorViewModel {
    
    // MARK: - View State Types
    
    enum ViewState {
        case form
        case loading
        case streaming
    }
    
    // MARK: - Dependencies
    
    private let apiClient: any APIClientProtocol
    
    // MARK: - Published State
    
    // View State
    var viewState: ViewState = .form
    var errorMessage: String?
    var showingError: Bool = false
    var showingDateSheet: Bool = false
    var sheetDetent: PresentationDetent = .fraction(0.7)
    
    // Form State
    var description: String = ""
    var dueDate: Date = Date()
    var inconveniences: String = ""
    var dailyAvailableTime: String = ""
    
    // Streaming State
    var streamingState = KitStreamingState()
    var isCancelled: Bool = false
    
    // MARK: - Internal State
    
    private var streamingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(apiClient: any APIClientProtocol, initialDate: Date? = nil) {
        self.apiClient = apiClient
        if let initialDate {
            self.dueDate = initialDate
        }
    }
    
    // MARK: - Computed Properties
    
    var todayStart: Date {
        Calendar.current.startOfDay(for: .now)
    }
    
    var isDateInPast: Bool {
        dueDate < todayStart
    }
    
    var isFormValid: Bool {
        !description.isEmpty && !isDateInPast
    }
    
    var toolbarTitle: String {
        switch viewState {
        case .form: return "Nuevo Kit"
        case .loading, .streaming: return "Creando tu Kit"
        }
    }
    
    var showsCancelButton: Bool {
        switch viewState {
        case .form:
            return true
        case .loading:
            return true
        case .streaming:
            return !streamingState.isComplete
        }
    }
    
    var cancelButtonTitle: String {
        viewState == .form ? "Cerrar" : "Cancelar"
    }
    
    // MARK: - Actions
    
    func createKit(token: String) {
        // Validación básica
        guard !description.isEmpty else { return }
        
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
                                handleError(event.error ?? "Error al conectar con la IA")
                            } else {
                                // Si ya estamos en streaming, el error se muestra en el estado del streaming
                                streamingState.setError(mapErrorMessage(event.error ?? "Error desconocido"))
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
    
    func cancelGeneration(modelContext: ModelContext) {
        // Marcar como cancelado
        isCancelled = true
        
        // Cancelar la tarea de streaming si existe
        streamingTask?.cancel()
        streamingTask = nil
        
        // Manejar el kit que puede haberse creado en el servidor
        if let kitId = streamingState.kitId {
            // Caso 1: Ya tenemos el kitId (el servidor completó) - eliminar directamente
            deleteKitById(kitId, in: modelContext)
        } else if viewState == .streaming || viewState == .loading {
            // Caso 2: No tenemos kitId pero estábamos en proceso
            // El servidor puede crear el kit - marcar sesión como cancelada
            markSessionAsCancelled()
        }
        
        // Resetear estado si no vamos a cerrar la vista inmediatamente (aunque la vista probablemente llame a dismiss)
        if viewState != .form {
            // Volver al formulario desde loading o streaming (sin animación para evitar parpadeo si se cierra)
            viewState = .form
            streamingState.reset()
        }
    }
    
    func saveKit(in modelContext: ModelContext) -> Goal? {
        guard let kitDTO = streamingState.kit else { return nil }
        
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
            return goalEntity.toGoal()
        } catch {
            #if DEBUG
            print("❌ Error al guardar en SwiftData: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleError(_ error: Any) {
        if let str = error as? String {
            errorMessage = mapErrorMessage(str)
        } else if let err = error as? Error {
            errorMessage = mapErrorMessage(err)
        } else {
            errorMessage = "Ha ocurrido un error inesperado"
        }
        showingError = true
    }
    
    private func mapErrorMessage(_ error: Any) -> String {
        if let str = error as? String {
            return str
        }
        
        guard let error = error as? Error else {
            return "Error desconocido"
        }
        
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
    
    /// Elimina un kit por su ID creando una entidad local marcada como eliminada
    private func deleteKitById(_ kitId: UUID, in modelContext: ModelContext) {
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
}

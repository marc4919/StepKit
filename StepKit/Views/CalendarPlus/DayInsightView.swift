//
//  DayInsightView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//

import SwiftUI
import FoundationModels

struct DayInsightView: View {
    let selectedDate: Date
    let steps: [StepEntity]
    let goals: [GoalEntity]

    @State private var insight: String?
    @State private var isLoading = false
    @State private var lastGeneratedHash: Int?
    
    /// Referencia al modelo del sistema para verificar disponibilidad
    private let model = SystemLanguageModel.default

    
    // Crear un hash único basado en los datos que afectan el insight
    // Ordenamos los arrays para asegurar que el hash sea estable independientemente del orden
    private var contentHash: Int {
        var hasher = Hasher()
        selectedDate.hash(into: &hasher)
        
        // Ordenar steps por ID para hash estable
        let sortedSteps = steps.sorted { $0.id.uuidString < $1.id.uuidString }
        sortedSteps.forEach { step in
            step.id.hash(into: &hasher)
            step.isCompleted.hash(into: &hasher)
            step.estimateMinutes.hash(into: &hasher)
        }
        
        // Ordenar goals por ID para hash estable
        let sortedGoals = goals.sorted { $0.id.uuidString < $1.id.uuidString }
        sortedGoals.forEach { goal in
            goal.id.hash(into: &hasher)
            goal.computedProgress.hash(into: &hasher)
        }
        
        return hasher.finalize()
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let insight, !insight.isEmpty {
                insightCard(insight)
            } else {
                emptyStateView
            }
        }
        .frame(minHeight: 60)
        .task(id: contentHash) {
            // Evitar regenerar si ya tenemos el mismo hash
            guard lastGeneratedHash != contentHash else { return }
            
            await generateInsight()
            lastGeneratedHash = contentHash
        }
    }
    
    private var emptyStateView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Text("No hay datos para analizar este día")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var loadingView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(LinearGradient.accentGradient)
                .symbolEffect(.pulse, options: .repeating)

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Analizando tu día...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.accentWithOpacity( 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LinearGradient.accentWithOpacity( 0.2), lineWidth: 1)
        )
    }

    private func insightCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(LinearGradient.accentGradient)
                .symbolEffect(.pulse, options: .repeating)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.accentWithOpacity( 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LinearGradient.accentWithOpacity( 0.2), lineWidth: 1)
        )
    }

    private func generateInsight() async {
        // Capturar el hash al inicio para verificar si los datos cambiaron durante la carga
        let currentHash = contentHash

        // Verificar si hay datos para analizar
        guard !steps.isEmpty || !goals.isEmpty else {
            insight = nil
            lastGeneratedHash = currentHash
            return
        }

        // Prevenir múltiples llamadas simultáneas
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }
        
        // Verificar disponibilidad del modelo antes de intentar usarlo
        guard model.availability == .available else {
            // Si el modelo no está disponible, no mostrar insight
            if contentHash == currentHash {
                insight = nil
                lastGeneratedHash = currentHash
            }
            return
        }

        do {
            let session = LanguageModelSession()

            let pendingSteps = steps.filter { !$0.isCompleted }
            let completedSteps = steps.filter { $0.isCompleted }
            let dateDescription = formatDate(selectedDate)

            // Construir contexto narrativo
            let situationContext = buildSituationContext(
                pending: pendingSteps.count,
                completed: completedSteps.count,
                goals: goals
            )

            let prompt = """
            Situación del usuario para \(dateDescription): \(situationContext)

            Genera UNA frase (8-15 palabras) que oriente al usuario.

            Tono: profesional, calmado, directo. Como un asistente competente.

            Debe ser:
            - Clara y práctica (qué hacer o cómo enfocar el día)
            - Serena pero NO cursi
            - Útil, con información real de la situación

            Prohibido:
            - Motivación vacía ("¡Tú puedes!", "Ánimo")
            - Metáforas o poesía ("el camino", "tu luz")
            - Espiritualidad o autoayuda
            - Números exactos o porcentajes
            - Emojis

            Ejemplos de tono correcto:
            - "Día ligero, buen momento para adelantar algo del objetivo principal."
            - "Varias cosas hoy. Empieza por la más corta para coger ritmo."
            - "Ya has avanzado bastante, cierra lo que queda y descansa."

            Responde SOLO con la frase, sin comillas ni ningún otro carácter.
            """

            let response = try await session.respond(to: prompt)
            var trimmedContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Eliminar comillas si las incluye
            let quoteChars = "\"'\u{201C}\u{201D}\u{2018}\u{2019}\u{00AB}\u{00BB}"
            trimmedContent = trimmedContent.trimmingCharacters(in: CharacterSet(charactersIn: quoteChars))

            // Solo actualizar si el hash no cambió mientras cargábamos
            if contentHash == currentHash {
                insight = trimmedContent.isEmpty ? nil : trimmedContent
                lastGeneratedHash = currentHash
            }
        } catch {
            // Solo actualizar si el hash no cambió mientras cargábamos
            if contentHash == currentHash {
                insight = nil
                lastGeneratedHash = currentHash
            }
        }
    }

    private func buildSituationContext(pending: Int, completed: Int, goals: [GoalEntity]) -> String {
        var parts: [String] = []

        // Situación de pasos (narrativa, no numérica)
        if completed > 0 && pending == 0 {
            parts.append("ha completado todo lo previsto")
        } else if completed > pending {
            parts.append("lleva buen ritmo, queda poco")
        } else if pending > 0 && completed > 0 {
            parts.append("está avanzando paso a paso")
        } else if pending > 3 {
            parts.append("tiene un día con bastantes cosas")
        } else if pending > 0 {
            parts.append("tiene algunas cosas pendientes")
        }

        // Situación de objetivos
        if let goal = goals.first {
            let progress = goal.computedProgress
            if progress >= 0.9 {
                parts.append("muy cerca de completar un objetivo")
            } else if progress >= 0.5 {
                parts.append("a mitad de camino en su objetivo")
            } else if progress > 0 {
                parts.append("comenzando un nuevo objetivo")
            }
        }

        return parts.isEmpty ? "día tranquilo sin tareas" : parts.joined(separator: ", ")
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Mañana"
        } else {
            return date.formatted(.dateTime.weekday(.wide).day().month())
        }
    }
}

#Preview {
    DayInsightView(
        selectedDate: Date(),
        steps: [],
        goals: []
    )
    .padding()
}

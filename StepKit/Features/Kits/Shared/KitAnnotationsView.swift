//
//  KitAnnotationsView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 7/12/25.
//

import SwiftUI
import SwiftData

struct KitAnnotationsView: View {
    let goal: Goal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var newAnnotation: String = ""
    @State private var annotations: [String] = []
    @FocusState private var isTextFieldFocused: Bool


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input field
                inputSection

                // Lista de anotaciones
                if annotations.isEmpty {
                    emptyState
                } else {
                    annotationsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Anotaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAnnotations()
            }
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        HStack(spacing: 12) {
            TextField("Escribe una nota...", text: $newAnnotation, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isTextFieldFocused)
                .submitLabel(.send)
                .writingToolsBehavior(.complete)
                .onSubmit {
                    addAnnotation()
                }

            Button {
                addAnnotation()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        newAnnotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.tertiaryLabel)
                            : Color.accentColor
                    )
            }
            .disabled(newAnnotation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.accentWithOpacity( 0.6))

            Text("Sin anotaciones")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Agrega notas personales para este kit")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Annotations List
    private var annotationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(annotations.enumerated(), id: \.offset) { index, annotation in
                    annotationCard(annotation, index: index)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Annotation Card
    private func annotationCard(_ annotation: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)

            Text(annotation)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                deleteAnnotation(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions
    private func addAnnotation() {
        let trimmed = newAnnotation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spring(response: 0.3)) {
            annotations.insert(trimmed, at: 0)
            newAnnotation = ""
            saveAnnotations()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteAnnotation(at index: Int) {
        withAnimation(.spring(response: 0.3)) {
            annotations.remove(at: index)
            saveAnnotations()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Persistence
    private func loadAnnotations() {
        // Cargar desde UserDefaults usando el ID del goal
        let key = "kit_annotations_\(goal.id)"
        if let saved = UserDefaults.standard.stringArray(forKey: key) {
            annotations = saved
        }
    }

    private func saveAnnotations() {
        let key = "kit_annotations_\(goal.id)"
        UserDefaults.standard.set(annotations, forKey: key)
    }
}

#Preview {
    KitAnnotationsView(goal: .preview)
}

//
//  KitCreationStreamingProgress.swift
//  StepKit
//
//  Extracted from KitCreatorView.swift
//

import SwiftUI

struct KitCreationStreamingProgress: View {
    @Binding var streamingState: KitStreamingState
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
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
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                        .symbolEffect(.variableColor.cumulative, options: .repeating)
                }
            }

            Text(streamingState.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: streamingState.statusText)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Kit Title Section
    
    private func kitTitleSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .bold()
                .foregroundStyle(.primary)

            if let kpi = streamingState.kpi {
                Text(kpi)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let days = streamingState.horizonDays {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("\(days) días")
                        .font(.caption)
                }
                .foregroundStyle(Color.accentColor)
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
                    .foregroundStyle(Color.accentColor)

                Text("Pasos")
                    .font(.headline)

                Spacer()

                if let total = streamingState.totalSteps {
                    Text("\(streamingState.steps.count) de \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                ForEach(streamingState.steps.enumerated(), id: \.offset) { index, step in
                    StreamingStepRowPreview(step: step, index: index)
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
    
    // MARK: - Loading Next Step
    
    private var loadingNextStep: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.accentColor)

            Text("Generando siguiente paso...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(spacing: 12) {
            Button {
                onSave()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Ver mi Kit")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .glowShadow(opacity: 0.3, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("kitCreator.save")

            Button {
                onDiscard()
            } label: {
                Text("Descartar kit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("kitCreator.discard")
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(streamingState.error ?? "Ha ocurrido un error")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onDiscard()
            } label: {
                Text("Volver")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

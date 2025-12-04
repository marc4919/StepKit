//
//  GoalDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    @State private var showingExtendedInfo = false
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    private let glowColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header con icono y título
                headerSection
                
                // Sección de pasos
                stepsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingExtendedInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(accentBlue)
                }
            }
        }
        .sheet(isPresented: $showingExtendedInfo) {
            ExtendedKitInfoView(goal: goal)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icono con progreso
            ZStack {
                // Glow exterior
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goal.isCompleted ? Color.green.opacity(0.2) : accentHighlight.opacity(0.2),
                                goal.isCompleted ? Color.green.opacity(0.05) : accentBlue.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                
                // Progreso circular
                Circle()
                    .stroke(
                        goal.isCompleted ? Color.green.opacity(0.15) : accentBlue.opacity(0.15),
                        lineWidth: 6
                    )
                    .frame(width: 72, height: 72)
                
                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(
                        goal.isCompleted
                            ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                
                // Contenido central
                if goal.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(accentBlue)
                }
            }
            
            // Título y KPI
            VStack(spacing: 8) {
                Text(goal.planTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(goal.kpi)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            
            // Contador de pasos
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundColor(accentBlue)
                
                Text("\(goal.steps.filter { $0.isCompleted }.count) de \(goal.steps.count) pasos completados")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header de sección
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(accentBlue)
                
                Text("Pasos")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(goal.steps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            
            if goal.steps.isEmpty {
                // Estado vacío
                emptyStepsView
            } else {
                // Lista de pasos
                VStack(spacing: 0) {
                    ForEach(Array(goal.steps.enumerated()), id: \.element.id) { index, step in
                        NavigationLink {
                            StepDetailView(step: step, stepNumber: index + 1)
                        } label: {
                            stepRow(step, index: index + 1, isLast: index == goal.steps.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Empty Steps View
    private var emptyStepsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentHighlight.opacity(0.6), accentBlue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No hay pasos definidos")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Step Row
    private func stepRow(_ step: Step, index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Indicador de paso
                ZStack {
                    Circle()
                        .fill(step.isCompleted ? Color.green.opacity(0.1) : accentBlue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if step.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(index)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(accentBlue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.stepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(step.description.short)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Tiempo estimado
                    if step.estimateMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatMinutes(step.estimateMinutes))
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if !isLast {
                Divider()
                    .padding(.leading, 74)
            }
        }
    }
    
    // MARK: - Helpers
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) h"
            } else {
                return "\(hours)h \(remainingMinutes)min"
            }
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: .preview)
    }
}

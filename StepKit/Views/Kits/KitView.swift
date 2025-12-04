//
//  KitView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI
import UIKit

/// Vista de detalle de un kit con sus pasos (optimizada para NavigationSplitView)
struct KitView: View {
    let goal: Goal
    let steps: [Step]
    @Binding var selectedStep: Step?
    
    // Colores del tema
    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentHighlight = Color(red: 0.55, green: 0.82, blue: 1.0)
    
    var body: some View {
        List(selection: $selectedStep) {
            // Header con info del goal
            Section {
                goalHeaderView
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            
            // Pasos del kit
            Section {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, index: index + 1)
                        .tag(step)
                }
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(accentBlue)
                    
                    Text("Pasos")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(steps.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Mostrar info extendida
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(accentBlue)
                }
            }
        }
    }
    
    // MARK: - Goal Header
    private var goalHeaderView: some View {
        VStack(spacing: 16) {
            // Icono con progreso
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                goal.isCompleted ? Color.green.opacity(0.2) : accentHighlight.opacity(0.2),
                                goal.isCompleted ? Color.green.opacity(0.05) : accentBlue.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(
                        goal.isCompleted ? Color.green.opacity(0.15) : accentBlue.opacity(0.15),
                        lineWidth: 5
                    )
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(
                        goal.isCompleted
                            ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [accentHighlight, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                if goal.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(accentBlue)
                }
            }
            
            // KPI
            Text(goal.kpi)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Contador de pasos
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(accentBlue)
                
                Text("\(steps.filter { $0.isCompleted }.count) de \(steps.count) completados")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Step Row
    private func stepRow(_ step: Step, index: Int) -> some View {
        HStack(spacing: 14) {
            // Indicador de paso
            ZStack {
                Circle()
                    .fill(step.isCompleted ? Color.green.opacity(0.1) : accentBlue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                if step.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
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
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedStep = step
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        KitView(
            goal: .preview,
            steps: [.preview, .previewPending],
            selectedStep: .constant(nil)
        )
    }
}

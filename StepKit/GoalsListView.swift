//
//  GoalsListView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 13/10/25.
//

import SwiftUI

struct Goal: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let progress: Double
    let isCompleted: Bool
    let dueDate: Date?
}

struct Step: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let isCompleted: Bool
    let goalId: UUID
}

struct GoalsListView: View {
    @State private var goals: [Goal] = [
        Goal(title: "Caminar 10,000 pasos diarios", description: "Mantener un estilo de vida activo", progress: 0.75, isCompleted: false, dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())),
        Goal(title: "Leer 2 libros este mes", description: "Mejorar conocimientos y cultura", progress: 0.5, isCompleted: false, dueDate: Calendar.current.date(byAdding: .day, value: 20, to: Date())),
        Goal(title: "Aprender SwiftUI", description: "Dominar el desarrollo iOS", progress: 0.3, isCompleted: false, dueDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())),
        Goal(title: "Hacer ejercicio 3 veces por semana", description: "Mantener buena forma física", progress: 1.0, isCompleted: true, dueDate: nil)
    ]
    
    @State private var selectedGoal: Goal?
    @State private var selectedStep: Step?
    @State private var showingFastCreator = false
    
    // Ejemplo de pasos para el objetivo seleccionado
    private var steps: [Step] {
        guard let selectedGoal = selectedGoal else { return [] }
        return [
            Step(title: "Paso 1", description: "Primer paso del objetivo", isCompleted: true, goalId: selectedGoal.id),
            Step(title: "Paso 2", description: "Segundo paso del objetivo", isCompleted: true, goalId: selectedGoal.id),
            Step(title: "Paso 3", description: "Tercer paso del objetivo", isCompleted: false, goalId: selectedGoal.id),
            Step(title: "Paso 4", description: "Cuarto paso del objetivo", isCompleted: false, goalId: selectedGoal.id)
        ]
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            if let selectedGoal = selectedGoal {
                ContentView(goal: selectedGoal)
            } else {
                ContentUnavailableView(
                    "Selecciona un Objetivo",
                    systemImage: "list.bullet",
                    description: Text("Elige un objetivo para ver sus pasos")
                )
            }
        } detail: {
            if let selectedStep = selectedStep {
                NavigationStack {
                    StepDetailView()
                        .navigationTitle(selectedStep.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                ContentUnavailableView(
                    "Selecciona un Paso",
                    systemImage: "doc.text",
                    description: Text("Elige un paso para ver sus detalles")
                )
            }
        }
        .fullScreenCover(isPresented: $showingFastCreator) {
            FastCreatorView()
        }
    }
    
    // MARK: - Sidebar View
    @ViewBuilder
    private func SidebarView() -> some View {
        if goals.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "target")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Da el primer paso")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                showingFastCreator = true
            }
            .navigationTitle("Mis Objetivos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFastCreator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } else {
            List(selection: $selectedGoal) {
                ForEach(goals) { goal in
                    GoalRowView(goal: goal)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .tag(goal)
                }
                .onDelete(perform: deleteGoals)
            }
            .navigationTitle("Mis Objetivos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFastCreator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private func ContentView(goal: Goal) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Información del objetivo
                GoalDetailView(goal: goal)
                
                // Separador
                Divider()
                    .padding(.horizontal)
                
                // Lista de pasos
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Pasos")
                            .font(.headline)
                            .padding(.horizontal)
                        Spacer()
                    }
                    
                    List(steps, selection: $selectedStep) { step in
                        StepRowView(step: step)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .tag(step)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 300)
                }
                .padding(.top)
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: selectedGoal) { oldValue, newValue in
            selectedStep = nil
        }
    }
    
    private func addGoal() {
        let newGoal = Goal(
            title: "Nuevo Objetivo",
            description: "Descripción del objetivo",
            progress: 0.0,
            isCompleted: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
        goals.append(newGoal)
        selectedGoal = newGoal
    }
    
    private func deleteGoals(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        if let selectedGoal = selectedGoal,
           !goals.contains(selectedGoal) {
            self.selectedGoal = nil
        }
    }
}

struct GoalRowView: View {
    let goal: Goal
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(goal.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(goal.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if let dueDate = goal.dueDate {
                            Text(dueDate, style: .date)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            if !goal.isCompleted {
                ProgressView(value: goal.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 0.8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(goal.isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct StepRowView: View {
    let step: Step
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(step.isCompleted ? .green : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(step.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isCompleted ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    GoalsListView()
}

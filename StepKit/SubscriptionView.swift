//
//  SubscriptionView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//

import SwiftUI

struct SubscriptionView: View {
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header con beneficios premium
                VStack(spacing: 24) {
                    // Icono y título principal
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 100, height: 100)
                            )
                        
                        VStack(spacing: 4) {
                            Text("StepKit Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Desbloquea todo el potencial")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Lista de beneficios
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "infinity",
                            title: "Objetivos ilimitados",
                            description: "Crea tantos objetivos como quieras"
                        )
                        
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Análisis avanzado",
                            description: "Estadísticas detalladas de tu progreso"
                        )
                        
                        FeatureRow(
                            icon: "bell.badge",
                            title: "Recordatorios personalizados",
                            description: "Notificaciones inteligentes adaptadas"
                        )
                        
                        FeatureRow(
                            icon: "icloud",
                            title: "Sincronización en la nube",
                            description: "Accede a tus datos desde cualquier dispositivo"
                        )
                        
                        FeatureRow(
                            icon: "star.circle.fill",
                            title: "Características exclusivas",
                            description: "Acceso anticipado a nuevas funciones"
                        )
                    }
                }
                
                // Plan de suscripción
                VStack(spacing: 16) {
                    Text("Plan Premium")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    PlanCard(
                        plan: .monthly,
                        isSelected: true,
                        isPopular: false
                    ) {
                        // No action needed since there's only one plan
                    }
                }
                
                // Botón de suscripción
                VStack(spacing: 16) {
                    Button {
                        subscribeToPlan()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Procesando..." : "Comenzar prueba gratuita")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    // Texto legal
                    VStack(spacing: 4) {
                        Text("7 días gratis, después €4.99/mes")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("Cancela en cualquier momento")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Suscripción")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func subscribeToPlan() {
        isLoading = true
        
        // Simular procesamiento
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            // Implementar lógica de suscripción aquí
            print("Suscribiendo al plan mensual")
        }
    }
}

// MARK: - Subscription Plan
enum SubscriptionPlan: CaseIterable {
    case monthly
    case yearly
    
    var title: String {
        switch self {
        case .monthly:
            return "Mensual"
        case .yearly:
            return "Anual"
        }
    }
    
    var price: String {
        switch self {
        case .monthly:
            return "€4.99"
        case .yearly:
            return "€29.99"
        }
    }
    
    var displayPrice: String {
        switch self {
        case .monthly:
            return "€4.99/mes"
        case .yearly:
            return "€29.99/año"
        }
    }
    
    var savings: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Ahorra 50%"
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isPopular: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Badge de popular
                if isPopular {
                    HStack {
                        Spacer()
                        Text("MÁS POPULAR")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        Spacer()
                    }
                    .padding(.top, -8)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(plan.displayPrice)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? .blue : .secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : Color(.systemGray5),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SubscriptionView()
}

//
//  ProfileView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 14/10/25.
//

import SwiftUI

struct ProfileView: View {
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header del perfil
                    VStack(spacing: 16) {
                        // Avatar del usuario
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 4) {
                            Text("Usuario")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Versión gratuita")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Botón de suscripción
                    NavigationLink(destination: SubscriptionView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Desbloquea StepKit Pro")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Accede a todas las funciones premium")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Separador
                    Divider()
                        .padding(.horizontal)
                    
                    // Botones de configuración
                    VStack(spacing: 16) {
                        // Términos de uso
                        Button {
                            showingTermsOfService = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("Términos de uso")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Políticas de privacidad
                        Button {
                            showingPrivacyPolicy = true
                        } label: {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                Text("Políticas de privacidad")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Cerrar sesión
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                Text("Cerrar sesión")
                                    .font(.body)
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Cerrar sesión", isPresented: $showingSignOutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Cerrar sesión", role: .destructive) {
                    // Acción de cerrar sesión
                    signOut()
                }
            } message: {
                Text("¿Estás seguro de que quieres cerrar sesión?")
            }
        }
    }
    
    private func signOut() {
        // Implementar lógica de cerrar sesión
        print("Cerrando sesión...")
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Términos de Uso de StepKit")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Aceptación de los términos")
                            .font(.headline)
                        
                        Text("Al usar StepKit, aceptas estos términos de uso. Si no estás de acuerdo, no uses la aplicación.")
                            .font(.body)
                        
                        Text("2. Uso de la aplicación")
                            .font(.headline)
                        
                        Text("StepKit está diseñado para ayudarte a gestionar y alcanzar tus objetivos personales. Debes usar la aplicación de manera responsable y legal.")
                            .font(.body)
                        
                        Text("3. Privacidad")
                            .font(.headline)
                        
                        Text("Respetamos tu privacidad. Para más información, consulta nuestras Políticas de Privacidad.")
                            .font(.body)
                        
                        Text("4. Limitación de responsabilidad")
                            .font(.headline)
                        
                        Text("StepKit se proporciona 'tal como está'. No garantizamos que el servicio sea ininterrumpido o libre de errores.")
                            .font(.body)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Términos de Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Políticas de Privacidad")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Información que recopilamos")
                            .font(.headline)
                        
                        Text("Recopilamos información que nos proporcionas directamente, como tus objetivos, progreso y preferencias dentro de la aplicación.")
                            .font(.body)
                        
                        Text("2. Cómo usamos tu información")
                            .font(.headline)
                        
                        Text("Utilizamos tu información para proporcionarte el servicio, mejorar la aplicación y personalizar tu experiencia.")
                            .font(.body)
                        
                        Text("3. Compartir información")
                            .font(.headline)
                        
                        Text("No vendemos, intercambiamos ni transferimos tu información personal a terceros sin tu consentimiento.")
                            .font(.body)
                        
                        Text("4. Seguridad")
                            .font(.headline)
                        
                        Text("Implementamos medidas de seguridad apropiadas para proteger tu información personal.")
                            .font(.body)
                        
                        Text("5. Contacto")
                            .font(.headline)
                        
                        Text("Si tienes preguntas sobre estas políticas, contáctanos a través de la aplicación.")
                            .font(.body)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Políticas de Privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}

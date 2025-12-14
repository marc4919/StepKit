//
//  PrivacyPolicyView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Políticas de Privacidad")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        policySection(number: "1", title: "Información que recopilamos", content: "Recopilamos información que nos proporcionas directamente, como tus objetivos, progreso y preferencias dentro de la aplicación.")
                        
                        policySection(number: "2", title: "Cómo usamos tu información", content: "Utilizamos tu información para proporcionarte el servicio, mejorar la aplicación y personalizar tu experiencia.")
                        
                        policySection(number: "3", title: "Compartir información", content: "No vendemos, intercambiamos ni transferimos tu información personal a terceros sin tu consentimiento.")
                        
                        policySection(number: "4", title: "Seguridad", content: "Implementamos medidas de seguridad apropiadas para proteger tu información personal.")
                        
                        policySection(number: "5", title: "Contacto", content: "Si tienes preguntas sobre estas políticas, contáctanos a través de la aplicación.")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Políticas de Privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private func policySection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

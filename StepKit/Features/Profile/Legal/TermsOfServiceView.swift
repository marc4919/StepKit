//
//  TermsOfServiceView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Términos de Uso de StepKit")
                        .font(.title2)
                        .bold()
                    
                    Text("Última actualización: Octubre 2024")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        termSection(number: "1", title: "Aceptación de los términos", content: "Al usar StepKit, aceptas estos términos de uso. Si no estás de acuerdo, no uses la aplicación.")
                        
                        termSection(number: "2", title: "Uso de la aplicación", content: "StepKit está diseñado para ayudarte a gestionar y alcanzar tus objetivos personales. Debes usar la aplicación de manera responsable y legal.")
                        
                        termSection(number: "3", title: "Privacidad", content: "Respetamos tu privacidad. Para más información, consulta nuestras Políticas de Privacidad.")
                        
                        termSection(number: "4", title: "Limitación de responsabilidad", content: "StepKit se proporciona 'tal como está'. No garantizamos que el servicio sea ininterrumpido o libre de errores.")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Términos de Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
    
    private func termSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

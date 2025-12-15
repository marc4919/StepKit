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
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Términos de Uso de StepKit")
                            .font(.title2)
                            .bold()
                        
                        Text("Última actualización: Diciembre 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        termSection(
                            number: "1",
                            title: "Aceptación de los Términos",
                            content: "Al descargar, instalar o utilizar la aplicación StepKit ('la Aplicación'), aceptas estar legalmente vinculado por estos Términos de Uso ('Términos'). Si no estás de acuerdo con estos Términos, no debes utilizar la Aplicación. Debes tener al menos 13 años (o la edad mínima requerida en tu país) para utilizar la Aplicación."
                        )
                        
                        termSection(
                            number: "2",
                            title: "Descripción del Servicio",
                            content: "StepKit es una herramienta diseñada para ayudarte a definir, gestionar y alcanzar tus objetivos personales mediante el desglose de tareas paso a paso. La Aplicación puede utilizar inteligencia artificial (IA) para generar sugerencias y planes. Estas sugerencias son generadas automáticamente y deben ser evaluadas por ti antes de seguirlas. StepKit no ofrece asesoramiento profesional (médico, legal, financiero, etc.)."
                        )
                        
                        termSection(
                            number: "3",
                            title: "Suscripciones y Pagos",
                            content: """
                            StepKit ofrece una versión gratuita y una suscripción 'Premium' con funciones adicionales.
                            
                            • **Prueba Gratuita**: Podemos ofrecer un período de prueba gratuito. Si no cancelas al menos 24 horas antes de que finalice la prueba, se te cobrará automáticamente el precio de la suscripción seleccionada.
                            • **Renovación Automática**: Las suscripciones se renuevan automáticamente a menos que desactives la renovación automática al menos 24 horas antes del final del período actual.
                            • **Cancelación**: Puedes gestionar y cancelar tus suscripciones en cualquier momento desde la configuración de tu cuenta de Apple ID en la App Store. La cancelación surtirá efecto al final del período de facturación actual.
                            • **Reembolsos**: Todas las compras son finales y gestionadas directamente por Apple. Para solicitar un reembolso, debes contactar con el soporte de Apple.
                            """
                        )
                        
                        termSection(
                            number: "4",
                            title: "Cuentas de Usuario",
                            content: "Para acceder a ciertas funciones, debes crear una cuenta (por ejemplo, mediante 'Sign in with Apple'). Eres responsable de mantener la confidencialidad de tu cuenta y de todas las actividades que ocurran bajo ella. Nos reservamos el derecho de suspender o eliminar tu cuenta si violas estos Términos."
                        )
                        
                        termSection(
                            number: "5",
                            title: "Contenido y Propiedad Intelectual",
                            content: "Tú conservas los derechos sobre el contenido que creas en la Aplicación. Sin embargo, al usar la Aplicación, nos otorgas una licencia para usar, almacenar y procesar dicho contenido únicamente para proporcionarte el servicio. El contenido generado por la IA de StepKit se proporciona para tu uso personal."
                        )
                        
                        termSection(
                            number: "6",
                            title: "Uso Prohibido",
                            content: "No debes usar la Aplicación para fines ilegales, dañinos o fraudulentos. Está prohibido intentar interferir con el funcionamiento de la Aplicación, realizar ingeniería inversa o usar la IA para generar contenido ofensivo o peligroso."
                        )
                        
                        termSection(
                            number: "7",
                            title: "Exención de Garantías",
                            content: "La Aplicación se proporciona 'tal cual' y 'según disponibilidad', sin garantías de ningún tipo, explícitas o implícitas. No garantizamos que la Aplicación esté libre de errores, sea segura o que el contenido generado por IA sea siempre preciso o útil."
                        )
                        
                        termSection(
                            number: "8",
                            title: "Limitación de Responsabilidad",
                            content: "En la medida máxima permitida por la ley, StepKit y sus desarrolladores no serán responsables por daños indirectos, incidentales, especiales o consecuentes derivados de tu uso o imposibilidad de uso de la Aplicación."
                        )
                        
                        termSection(
                            number: "9",
                            title: "Modificaciones",
                            content: "Podemos modificar estos Términos en cualquier momento. Te notificaremos sobre cambios importantes a través de la Aplicación. El uso continuado de la Aplicación después de dichos cambios constituye tu aceptación de los nuevos Términos."
                        )
                        
                        termSection(
                            number: "10",
                            title: "Contacto",
                            content: "Si tienes preguntas sobre estos Términos, contáctanos en support@stepkit.app."
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Términos de Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
    
    private func termSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(LocalizedStringKey(content)) // Use LocalizedStringKey to support markdown styling in text
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    TermsOfServiceView()
}

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
                        
                        Text("Última actualización: 30 de octubre de 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        termSection(
                            number: "1",
                            title: String(localized: "Aceptación de los Términos"),
                            content: String(localized: "Al descargar, instalar o utilizar la aplicación StepKit ('la Aplicación'), aceptas estar legalmente vinculado por estos Términos de Uso ('Términos'). Si no estás de acuerdo con estos Términos, no debes utilizar la Aplicación. Debes tener al menos 13 años (o la edad mínima requerida en tu país) para utilizar la Aplicación.")
                        )
                        
                        termSection(
                            number: "2",
                            title: String(localized: "Descripción del Servicio"),
                            content: String(localized: "StepKit es una herramienta diseñada para ayudarte a definir, gestionar y alcanzar tus objetivos personales mediante el desglose de tareas paso a paso. La Aplicación puede utilizar inteligencia artificial (IA) para generar sugerencias y planes. Estas sugerencias son generadas automáticamente y deben ser evaluadas por ti antes de seguirlas. StepKit no ofrece asesoramiento profesional (médico, legal, financiero, etc.).")
                        )
                        
                        termSection(
                            number: "3",
                            title: String(localized: "Suscripciones y Pagos"),
                            content: String(localized: "StepKit se puede usar gratis con hasta 2 Kits activos y 10 usos de la IA al mes. La suscripción StepKit Pro, mensual o anual, quita esos límites.\n\n• **Prueba gratuita**: si la suscripción incluye un periodo de prueba, se cobrará automáticamente al terminar salvo que la canceles al menos 24 horas antes.\n• **Precio y renovación**: el precio y la duración se muestran antes de suscribirte, y Apple los cobra a tu cuenta. La suscripción se renueva sola salvo que desactives la renovación al menos 24 horas antes del final del periodo actual.\n• **Cancelación**: puedes gestionarla o cancelarla en los ajustes de tu cuenta de Apple. La cancelación surte efecto al final del periodo pagado.\n• **Reembolsos**: los gestiona Apple. Para solicitar uno, contacta con el soporte de Apple.\n\nEstos Términos se aplican junto con el Acuerdo de licencia de usuario final estándar de Apple (EULA).")
                        )
                        
                        termSection(
                            number: "4",
                            title: String(localized: "Cuentas de Usuario"),
                            content: String(localized: "Para acceder a ciertas funciones, debes crear una cuenta (por ejemplo, mediante 'Sign in with Apple'). Eres responsable de mantener la confidencialidad de tu cuenta y de todas las actividades que ocurran bajo ella. Nos reservamos el derecho de suspender o eliminar tu cuenta si violas estos Términos.")
                        )
                        
                        termSection(
                            number: "5",
                            title: String(localized: "Contenido y Propiedad Intelectual"),
                            content: String(localized: "Tú conservas los derechos sobre el contenido que creas en la Aplicación. Sin embargo, al usar la Aplicación, nos otorgas una licencia para usar, almacenar y procesar dicho contenido únicamente para proporcionarte el servicio. El contenido generado por la IA de StepKit se proporciona para tu uso personal.")
                        )
                        
                        termSection(
                            number: "6",
                            title: String(localized: "Uso Prohibido"),
                            content: String(localized: "No debes usar la Aplicación para fines ilegales, dañinos o fraudulentos. Está prohibido intentar interferir con el funcionamiento de la Aplicación, realizar ingeniería inversa o usar la IA para generar contenido ofensivo o peligroso.")
                        )
                        
                        termSection(
                            number: "7",
                            title: String(localized: "Exención de Garantías"),
                            content: String(localized: "La Aplicación se proporciona 'tal cual' y 'según disponibilidad', sin garantías de ningún tipo, explícitas o implícitas. No garantizamos que la Aplicación esté libre de errores, sea segura o que el contenido generado por IA sea siempre preciso o útil.")
                        )
                        
                        termSection(
                            number: "8",
                            title: String(localized: "Limitación de Responsabilidad"),
                            content: String(localized: "En la medida máxima permitida por la ley, StepKit y sus desarrolladores no serán responsables por daños indirectos, incidentales, especiales o consecuentes derivados de tu uso o imposibilidad de uso de la Aplicación.")
                        )
                        
                        termSection(
                            number: "9",
                            title: String(localized: "Modificaciones"),
                            content: String(localized: "Podemos modificar estos Términos en cualquier momento. Te notificaremos sobre cambios importantes a través de la Aplicación. El uso continuado de la Aplicación después de dichos cambios constituye tu aceptación de los nuevos Términos.")
                        )
                        
                        termSection(
                            number: "10",
                            title: String(localized: "Contacto"),
                            content: String(localized: "Si tienes preguntas sobre estos Términos, contáctanos en marcgt.dev@icloud.com.")
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

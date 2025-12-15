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
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Política de Privacidad")
                            .font(.title2)
                            .bold()
                        
                        Text("Última actualización: Diciembre 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        policySection(
                            number: "1",
                            title: "Introducción",
                            content: "En StepKit, respetamos tu privacidad y nos comprometemos a proteger tus datos personales. Esta Política de Privacidad explica cómo recopilamos, usamos y compartimos tu información cuando utilizas nuestra aplicación móvil."
                        )
                        
                        policySection(
                            number: "2",
                            title: "Información que Recopilamos",
                            content: """
                            Recopilamos la siguiente información:
                            
                            • **Información de Cuenta**: Cuando te registras (por ejemplo, con Apple), podemos recibir tu nombre y correo electrónico si eliges compartirlos.
                            • **Datos de Uso**: Información sobre cómo interactúas con la app, tus objetivos creados, progreso y preferencias.
                            • **Información Técnica**: Modelo de dispositivo, versión de sistema operativo e identificadores anónimos para diagnóstico de errores.
                            • **Datos de Suscripción**: Apple procesa tus pagos y gestiona tu suscripción; nosotros solo recibimos el estado de tu suscripción y la fecha de vencimiento.
                            """
                        )
                        
                        policySection(
                            number: "3",
                            title: "Uso de la Información",
                            content: """
                            Utilizamos tu información para:
                            
                            • Proporcionar, mantener y mejorar el servicio.
                            • Sincronizar tus datos entre tus dispositivos.
                            • Procesar tus solicitudes de generación de contenido mediante IA.
                            • Comunicarnos contigo sobre actualizaciones o soporte.
                            • Detectar y prevenir fraudes o abusos.
                            """
                        )
                        
                        policySection(
                            number: "4",
                            title: "Compartir Información",
                            content: """
                            No vendemos tu información personal. Podemos compartir información con:
                            
                            • **Proveedores de Servicios**: Utilizamos servicios de terceros para el alojamiento de datos (ej. Railway) y procesamiento de IA. Estos proveedores solo tienen acceso a la información necesaria para realizar sus funciones y están obligados a protegerla.
                            • **Requisitos Legales**: Si es requerido por ley o para proteger nuestros derechos.
                            """
                        )
                        
                        policySection(
                            number: "4.1",
                            title: "Uso de Inteligencia Artificial Externa",
                            content: """
                            StepKit utiliza servicios de inteligencia artificial externos para generar planes personalizados de objetivos. Esta sección explica cómo y qué datos compartimos con estos servicios.
                            
                            **Datos que Compartimos:**
                            
                            • **Descripción de Objetivos**: La descripción detallada de tus objetivos personales que proporcionas al crear un kit.
                            • **Información Temporal**: Fechas objetivo, disponibilidad diaria de tiempo y zona horaria.
                            • **Obstáculos e Inconvenientes**: Información sobre obstáculos o inconvenientes que mencionas al crear tus objetivos.
                            
                            **Cómo Funciona:**
                            
                            Estos datos se envían de forma segura a nuestro servidor, que a su vez los procesa mediante servicios de IA de terceros para generar planes personalizados. Los datos se procesan únicamente para generar tu plan y no se utilizan para entrenar modelos de IA ni para fines publicitarios.
                            
                            **Tu Consentimiento:**
                            
                            Antes de usar funciones que requieren IA externa, te pedimos tu consentimiento explícito. Puedes revocar este consentimiento en cualquier momento desde la configuración de la aplicación, aunque esto limitará algunas funcionalidades.
                            
                            **Seguridad:**
                            
                            Todas las comunicaciones con nuestro servidor y los servicios de IA externos se realizan mediante conexiones cifradas (HTTPS). No almacenamos tus datos personales en los servicios de IA externos más allá de lo necesario para procesar tu solicitud.
                            """
                        )
                        
                        policySection(
                            number: "5",
                            title: "Seguridad de los Datos",
                            content: "Implementamos medidas de seguridad técnicas y organizativas para proteger tus datos. Sin embargo, ninguna transmisión por internet es 100% segura, por lo que no podemos garantizar seguridad absoluta."
                        )
                        
                        policySection(
                            number: "6",
                            title: "Tus Derechos",
                            content: "Dependiendo de tu ubicación, puedes tener derecho a acceder, corregir, eliminar o restringir el procesamiento de tus datos personales. Puedes eliminar tu cuenta y todos tus datos directamente desde la configuración de la aplicación."
                        )
                        
                        policySection(
                            number: "7",
                            title: "Privacidad de los Niños",
                            content: "Nuestra aplicación no está dirigida a niños menores de 13 años. No recopilamos conscientemente información personal de niños menores de 13 años."
                        )
                        
                        policySection(
                            number: "8",
                            title: "Cambios a esta Política",
                            content: "Podemos actualizar esta Política de Privacidad ocasionalmente. Te notificaremos sobre cambios significativos a través de la aplicación."
                        )
                        
                        policySection(
                            number: "9",
                            title: "Contacto",
                            content: "Si tienes preguntas sobre esta política, contáctanos en support@stepkit.app."
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Política de Privacidad")
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
    
    private func policySection(number: String, title: String, content: String) -> some View {
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
    PrivacyPolicyView()
}

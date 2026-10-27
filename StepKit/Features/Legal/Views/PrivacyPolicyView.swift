//
//  PrivacyPolicyView.swift
//  StepKit
//
//  Mismo texto que 05_launch/app-store/POLITICA-PRIVACIDAD.md (borrador del 27 oct 2026).
//  Los datos entre corchetes los completa el titular antes de publicar.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, body: String)] = [
        (String(localized: "Quién es el responsable"),
         String(localized: "StepKit es una app de Marc García Teodoro. Para cualquier cuestión de privacidad, escribe a marcgt.dev@icloud.com.")),
        (String(localized: "Qué datos tratamos"),
         String(localized: "• **Cuenta.** Inicias sesión con Apple. Nuestro servidor guarda un identificador que Apple genera para StepKit. Si compartes tu nombre o correo con Apple, se quedan en tu dispositivo y nuestro servidor no los guarda.\n• **Tu contenido.** Los Kits, pasos, avances, notas, bloqueos y sesiones que creas. Se guardan en tu dispositivo y en nuestro servidor para sincronizarlos entre tus dispositivos.\n• **Suscripción.** Apple gestiona el pago. Nosotros solo recibimos y guardamos el estado de tu suscripción (producto, vigencia y renovación) para saber si tienes StepKit Pro. Nunca vemos tus datos de pago.\n• **Uso de la IA.** Contamos cuántas veces usas la IA en la nube cada mes y los tokens consumidos, para aplicar los límites del plan gratuito y controlar costes. No guardamos el texto de tus conversaciones con el asistente en el servidor.\n\nNo usamos publicidad, analítica de terceros ni rastreo, y no vendemos datos.")),
        (String(localized: "Inteligencia artificial"),
         String(localized: "• **IA externa, solo con tu permiso.** Al crear un Kit o al escribir al asistente de un Kit, enviamos a nuestro servidor lo necesario para responderte: tu meta, fechas, tiempo disponible, obstáculos, el estado del plan y de tus avances, y tus mensajes. El servidor lo reenvía a un modelo de IA de terceros a través de OpenRouter, Inc. Usamos solo endpoints de **retención cero**: el proveedor no guarda la petición una vez respondida ni la usa para entrenar modelos. Los modelos actuales se ejecutan en Google Cloud Vertex AI, Amazon Bedrock o Microsoft Azure, preferentemente en centros de datos de la Unión Europea.\n• **En tu dispositivo (Apple Intelligence).** Al crear un Kit, StepKit puede usar el modelo de tu iPhone o iPad para estimar lo complejo que es tu objetivo. Eso no sale del dispositivo.\n\nTe pedimos permiso antes del primer envío. Sin él, el asistente del Kit y la creación de planes con IA no están disponibles. Puedes retirarlo cuando quieras en **Perfil > IA y privacidad**, y desde ese momento no se envía nada más.")),
        (String(localized: "Para qué y con qué base legal"),
         String(localized: "• **Prestar el servicio** (cuenta, sincronización y planes): ejecución del contrato (RGPD art. 6.1.b).\n• **Enviar tu contenido a la IA externa:** tu consentimiento (art. 6.1.a), que puedes retirar.\n• **Gestionar la suscripción:** ejecución del contrato (art. 6.1.b).\n• **Límites de uso, seguridad y prevención de abusos:** interés legítimo (art. 6.1.f).")),
        (String(localized: "Quién más trata tus datos"),
         String(localized: "Encargados del tratamiento que actúan siguiendo nuestras instrucciones:\n\n• **Railway Corporation:** alojamiento del servidor y de la base de datos, en un centro de datos de Ámsterdam (Unión Europea).\n• **OpenRouter, Inc.** y el proveedor del modelo (Google, Amazon o Microsoft): procesan las peticiones de IA cuando das permiso, con retención cero.\n• **Apple:** inicio de sesión, pagos y notificaciones de suscripción.\n\nAlgunos de estos proveedores están en Estados Unidos. Las transferencias se amparan en el Marco de Privacidad de Datos UE-EE. UU. o en cláusulas contractuales tipo.")),
        (String(localized: "Cuánto tiempo los guardamos"),
         String(localized: "Mientras tengas cuenta. Si borras un Kit, en el servidor queda marcado como borrado para que no reaparezca en tus otros dispositivos, y desaparece del todo al eliminar la cuenta. Si eliminas tu cuenta, borramos de inmediato todos tus datos del servidor y desvinculamos StepKit de tu Apple Account.")),
        (String(localized: "Tus derechos"),
         String(localized: "Puedes acceder a tus datos, rectificarlos, suprimirlos, oponerte o limitar su tratamiento, y pedir su portabilidad, escribiendo a marcgt.dev@icloud.com. Para borrar tu cuenta y todos tus datos no hace falta escribirnos: está en **Perfil > Eliminar cuenta**. También puedes reclamar ante la Agencia Española de Protección de Datos (aepd.es).\n\nEliminar la cuenta no cancela una suscripción de StepKit Pro. Para cancelarla, ve a Ajustes > Apple Account > Suscripciones.")),
        (String(localized: "Menores"),
         String(localized: "StepKit no está dirigida a menores de 14 años.")),
        (String(localized: "Seguridad"),
         String(localized: "Todas las conexiones van cifradas (HTTPS). El acceso al servidor está restringido y las credenciales de los servicios nunca están en la app.")),
        (String(localized: "Cambios"),
         String(localized: "Si cambiamos esta política de forma relevante, te avisaremos en la app antes de que el cambio se aplique."))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Política de privacidad")
                            .font(.title2)
                            .bold()
                        Text("Última actualización: 28 de octubre de 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            policySection(number: index + 1, title: section.title, content: section.body)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
                .readableContentWidth()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Política de privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func policySection(number: Int, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundStyle(.primary)
            // Ya traducido: se pasa como Markdown, no como clave de traducción.
            Text((try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(content))
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

//
//  StepKitTips.swift
//  StepKit
//
//  Consejos de primera vez (TipKit): salen una sola vez junto al botón que explican
//  y desaparecen en cuanto se usa ese botón o se cierran.
//

import SwiftUI
import TipKit

struct CreateKitTip: Tip {
    var title: Text { Text("Crea tu primer Kit") }
    var message: Text? { Text("Escribe una meta y una fecha. La IA te propone los pasos y los revisas antes de empezar.") }
    var image: Image? { Image(systemName: "plus.circle") }
}

struct StepActionsTip: Tip {
    var title: Text { Text("Tres acciones en cada paso") }
    var message: Text? { Text("Avance guarda lo que llevas. Atasco anota qué te frena. Completar cierra el paso.") }
    var image: Image? { Image(systemName: Symbols.note) }
}

struct KitAssistantTip: Tip {
    var title: Text { Text("Tu asistente del Kit") }
    var message: Text? { Text("Pregúntale cuando no sepas cómo seguir. Si propone cambiar el plan, decides tú.") }
    var image: Image? { Image(systemName: Symbols.assistant) }
}

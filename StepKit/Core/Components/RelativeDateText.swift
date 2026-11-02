//
//  RelativeDateText.swift
//  StepKit
//
//  «Hace 5 minutos» que se mantiene al día: un Text normal se queda en lo que decía al dibujarse.
//

import SwiftUI

struct RelativeDateText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            Text(date.formatted(.relative(presentation: .named)))
        }
    }
}

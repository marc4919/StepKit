//
//  StepDetailView.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on 8/10/25.
//

import SwiftUI

struct StepDetailView: View {
    @State var isExpanded: Bool = false
    var body: some View {
        ZStack {
            // Contenido principal
            VStack {
                Text("Detalle")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Botón flotante en esquina inferior derecha
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    GlassEffectContainer {
                        VStack {
                            if isExpanded {
                                Button{} label: {
                                    Image(systemName: "photo")
                                }
                                Button{} label: {
                                    Image(systemName: "video")
                                }
                                Button{} label: {
                                    Image(systemName: "link")
                                }
                            }
                            Button{
                                withAnimation{
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isExpanded ? "xmark" : "plus")
                                    .font(.title2)
                                    .bold()
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                    }
                    .padding(25)
                }
            }
        }
        .navigationTitle("Paso")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    StepDetailView()
}

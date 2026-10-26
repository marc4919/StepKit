//
//  StepDetailHeaderView.swift
//  StepKit
//
//  Created by Assistant on 2024-12-13.
//

import SwiftUI

struct StepDetailHeaderView: View {
    let stepTitle: String
    let stepNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Número de paso
            Text(String(localized: "Paso \(stepNumber)"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)

            // Título del step
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(.primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

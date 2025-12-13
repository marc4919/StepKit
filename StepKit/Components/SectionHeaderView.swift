//
//  SectionHeaderView.swift
//  StepKit
//
//  Created by StepKit Refactor.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let icon: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

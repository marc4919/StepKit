//
//  StreamingStepRowPreview.swift
//  StepKit
//
//  Extracted from KitCreatorView.swift
//

import SwiftUI

struct StreamingStepRowPreview: View {
    let step: StreamStepOutput
    let index: Int
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accentWithOpacity( 0.3))
                    .frame(width: 32, height: 32)

                Text("\(index + 1)")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.stepTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(step.description.short)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(step.estimateMinutes) min", systemImage: "clock")
                    Label(formatDeadline(step.suggestedDeadline), systemImage: "calendar")
                    Label(step.effortLevel, systemImage: "flame")
                }
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Helpers
    
    private func formatDeadline(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

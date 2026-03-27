import SwiftUI

struct AIResultView: View {
    let result: AIAnalysisResult

    private var signalColor: Color {
        switch result.signal {
        case .long: return .red
        case .short: return .green
        case .wait: return .gray
        }
    }

    private var confidenceColor: Color {
        if result.confidence >= 60 { return .green }
        if result.confidence >= 30 { return .orange }
        return .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.signalLabel)
                        .font(.headline).fontWeight(.bold)
                    Text(result.marketPhase)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("置信度").font(.caption2).foregroundStyle(.secondary)
                    Text("\(result.confidence)%")
                        .font(.title2).fontWeight(.bold).monospacedDigit()
                        .foregroundStyle(confidenceColor)
                }
            }

            // Confidence bar
            ProgressView(value: Double(result.confidence), total: 100)
                .tint(confidenceColor)

            // Summary
            Text(result.summary)
                .font(.subheadline)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            // Pattern
            if result.pattern != "暂无" {
                Text("形态: \(result.pattern)")
                    .font(.caption).foregroundStyle(.indigo)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            // Entry / Stop / Target
            if result.signal != .wait, let entry = result.entryPrice {
                HStack(spacing: 8) {
                    priceBox(label: "建议入场", value: entry, color: .primary)
                    priceBox(label: "止损位", value: result.stopLoss, color: .red)
                    priceBox(label: "目标位", value: result.target, color: .green)
                }
            }

            // Reasons
            VStack(alignment: .leading, spacing: 4) {
                ForEach(result.reasons, id: \.self) { reason in
                    Text(reason).font(.caption).foregroundStyle(.primary)
                }
            }

            // Warnings
            if !result.warnings.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            // Token usage
            if let usage = result.tokenUsage {
                Divider()
                HStack(spacing: 12) {
                    Text("Tokens: \((usage.prompt + usage.completion).formatted())")
                    if let cost = usage.cost {
                        Text("本次: $\(String(format: "%.4f", cost))")
                    }
                }
                .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(signalColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(signalColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func priceBox(label: String, value: Double?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value != nil ? String(format: "%.2f", value!) : "-")
                .font(.subheadline).fontWeight(.bold).monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

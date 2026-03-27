import SwiftUI

struct ScanResultsView: View {
    let results: [ScanResult]
    let useAI: Bool
    let onSelect: (ScanResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.fill").foregroundStyle(.orange)
                Text("Top 3 Price Action 选股").font(.subheadline).fontWeight(.bold)
                if useAI {
                    Text("AI 精选").font(.caption2).foregroundStyle(.indigo)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                }
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                Button { onSelect(result) } label: {
                    HStack(spacing: 12) {
                        // 排名
                        Text("\(index + 1)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom),
                                in: Circle()
                            )

                        // 信息
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(result.stock.name).font(.subheadline).fontWeight(.semibold)
                                Text(result.stock.code).font(.caption2).foregroundStyle(.secondary)
                                Text(result.signal == .long ? "做多" : "做空")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background((result.signal == .long ? Color.red : Color.green).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                    .foregroundStyle(result.signal == .long ? .red : .green)
                            }
                            HStack(spacing: 4) {
                                Text(result.pattern).font(.caption2).foregroundStyle(.indigo)
                                Text("·").foregroundStyle(.secondary)
                                Text("\(String(format: "%.2f", result.lastPrice)) (\(result.changePct >= 0 ? "+" : "")\(String(format: "%.2f", result.changePct))%)")
                                    .font(.caption2).monospacedDigit()
                                    .foregroundStyle(result.changePct >= 0 ? .red : .green)
                            }
                            if let reason = result.aiReason {
                                Text(reason).font(.caption2).foregroundStyle(.purple)
                            }
                        }

                        Spacer()

                        // 分数
                        VStack(spacing: 0) {
                            Text("\(result.aiScore ?? result.score)")
                                .font(.title3).fontWeight(.bold).foregroundStyle(.orange)
                            Text(result.aiScore != nil ? "AI分" : "评分")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Text("从成交额前100只主板股票中筛选 · 点击查看详情")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

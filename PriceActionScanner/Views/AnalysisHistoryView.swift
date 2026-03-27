import SwiftUI

struct AnalysisHistoryView: View {
    let onSelect: (StockItem) -> Void

    @State private var history: [AnalysisRecord] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView(
                        "暂无分析记录",
                        systemImage: "clock",
                        description: Text("使用 AI 分析后记录会出现在这里")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(history) { record in
                        Button {
                            onSelect(record.stock)
                        } label: {
                            HStack {
                                // Signal indicator
                                Circle()
                                    .fill(signalColor(record.result.signal))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(record.stock.name)
                                            .font(.subheadline).fontWeight(.medium)
                                        Text(record.stock.code)
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        Text(record.result.signalLabel)
                                            .font(.caption2)
                                            .foregroundStyle(signalColor(record.result.signal))
                                        Text("\(record.result.confidence)%")
                                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                                        Text(record.result.pattern)
                                            .font(.caption2).foregroundStyle(.indigo)
                                    }
                                }

                                Spacer()

                                Text(timeAgo(record.timestamp))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("分析历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                if !history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清除", role: .destructive) {
                            StorageService.shared.clearAnalysisHistory()
                            history = []
                        }
                    }
                }
            }
            .onAppear {
                history = StorageService.shared.getAnalysisHistory()
            }
        }
    }

    private func signalColor(_ signal: TradeSignalType) -> Color {
        switch signal {
        case .long: return .red
        case .short: return .green
        case .wait: return .gray
        }
    }

    private func timeAgo(_ timestamp: TimeInterval) -> String {
        let seconds = Date().timeIntervalSince1970 - timestamp / 1000
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
    }
}

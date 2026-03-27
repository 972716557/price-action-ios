import SwiftUI

struct StockSearchView: View {
    let onSelect: (StockItem) -> Void

    @State private var keyword = ""
    @State private var results: [StockItem] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !keyword.isEmpty && !searching {
                    Text("未找到相关股票")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(results) { stock in
                    Button {
                        onSelect(stock)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stock.name)
                                    .font(.body).foregroundStyle(.primary)
                                Text(stock.code)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(stock.market.uppercased())
                                .font(.caption2).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
            }
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索股票代码或名称")
            .onChange(of: keyword) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await search(keyword: newValue)
                }
            }
            .navigationTitle("搜索股票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay {
                if searching {
                    ProgressView()
                }
            }
        }
    }

    @MainActor
    private func search(keyword: String) async {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searching = true
        do {
            results = try await StockAPIService.shared.searchStocks(keyword: keyword)
        } catch {
            results = []
        }
        searching = false
    }
}

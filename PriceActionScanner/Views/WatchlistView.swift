import SwiftUI

struct WatchlistView: View {
    @ObservedObject var viewModel: WatchlistViewModel
    let onSelect: (StockItem) -> Void

    var body: some View {
        NavigationStack {
            List {
                if viewModel.watchlist.isEmpty {
                    ContentUnavailableView(
                        "暂无自选股",
                        systemImage: "star",
                        description: Text("在行情页面点击星标添加自选")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.watchlist) { stock in
                        Button {
                            onSelect(stock)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stock.name)
                                        .font(.body).fontWeight(.medium)
                                    Text(stock.code)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(stock.market.uppercased())
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            viewModel.remove(code: viewModel.watchlist[i].code)
                        }
                    }
                }
            }
            .navigationTitle("自选股")
            .toolbar {
                if !viewModel.watchlist.isEmpty {
                    EditButton()
                }
            }
            .onAppear {
                viewModel.reload()
            }
        }
    }
}

import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published var watchlist: [StockItem] = []

    init() {
        reload()
    }

    func reload() {
        watchlist = StorageService.shared.getWatchlist()
    }

    func add(_ stock: StockItem) {
        StorageService.shared.addToWatchlist(stock)
        reload()
    }

    func remove(code: String) {
        StorageService.shared.removeFromWatchlist(code: code)
        reload()
    }

    func isInWatchlist(code: String) -> Bool {
        watchlist.contains { $0.code == code }
    }

    func toggle(_ stock: StockItem) {
        if isInWatchlist(code: stock.code) {
            remove(code: stock.code)
        } else {
            add(stock)
        }
    }
}

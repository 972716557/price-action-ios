import Foundation

final class StorageService: ObservableObject {
    static let shared = StorageService()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let history = "pa_analysis_history"
        static let watchlist = "pa_watchlist"
        static let model = "openrouter_model"
        static let apiKey = "openrouter_api_key"
        static let scanResults = "pa_scan_results"
        static let scanTimestamp = "pa_scan_timestamp"
        static let lastStock = "pa_last_stock"
    }

    // MARK: - AI 模型

    @Published var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Keys.model) }
    }

    @Published var openRouterAPIKey: String {
        didSet { defaults.set(openRouterAPIKey, forKey: Keys.apiKey) }
    }

    // MARK: - 分析历史

    private let maxHistory = 50

    func getAnalysisHistory() -> [AnalysisRecord] {
        guard let data = defaults.data(forKey: Keys.history),
              let records = try? JSONDecoder().decode([AnalysisRecord].self, from: data) else {
            return []
        }
        return records
    }

    @discardableResult
    func saveAnalysisRecord(stock: StockItem, result: AIAnalysisResult) -> AnalysisRecord {
        let record = AnalysisRecord(
            id: "\(stock.code)-\(Int(Date().timeIntervalSince1970 * 1000))",
            stock: stock,
            result: result,
            timestamp: Date().timeIntervalSince1970 * 1000
        )
        var history = getAnalysisHistory()
        history.insert(record, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Keys.history)
        }
        return record
    }

    func clearAnalysisHistory() {
        defaults.removeObject(forKey: Keys.history)
    }

    // MARK: - 自选股

    func getWatchlist() -> [StockItem] {
        guard let data = defaults.data(forKey: Keys.watchlist),
              let items = try? JSONDecoder().decode([StockItem].self, from: data) else {
            return []
        }
        return items
    }

    func addToWatchlist(_ stock: StockItem) {
        var list = getWatchlist()
        guard !list.contains(where: { $0.code == stock.code }) else { return }
        list.append(stock)
        saveWatchlist(list)
    }

    func removeFromWatchlist(code: String) {
        let list = getWatchlist().filter { $0.code != code }
        saveWatchlist(list)
    }

    func isInWatchlist(code: String) -> Bool {
        getWatchlist().contains { $0.code == code }
    }

    private func saveWatchlist(_ list: [StockItem]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: Keys.watchlist)
        }
    }

    // MARK: - 上次查看的股票

    func getLastStock() -> StockItem? {
        guard let data = defaults.data(forKey: Keys.lastStock),
              let stock = try? JSONDecoder().decode(StockItem.self, from: data) else {
            return nil
        }
        return stock
    }

    func saveLastStock(_ stock: StockItem) {
        if let data = try? JSONEncoder().encode(stock) {
            defaults.set(data, forKey: Keys.lastStock)
        }
    }

    // MARK: - 扫描结果

    func getScanResults() -> [ScanResult] {
        guard let data = defaults.data(forKey: Keys.scanResults),
              let results = try? JSONDecoder().decode([ScanResult].self, from: data) else {
            return []
        }
        return results
    }

    func saveScanResults(_ results: [ScanResult]) {
        if let data = try? JSONEncoder().encode(results) {
            defaults.set(data, forKey: Keys.scanResults)
            defaults.set(Date().timeIntervalSince1970 * 1000, forKey: Keys.scanTimestamp)
        }
    }

    func getScanTimestamp() -> Date? {
        let ts = defaults.double(forKey: Keys.scanTimestamp)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }

    func clearScanResults() {
        defaults.removeObject(forKey: Keys.scanResults)
        defaults.removeObject(forKey: Keys.scanTimestamp)
    }

    // MARK: - Init

    private init() {
        self.selectedModel = defaults.string(forKey: Keys.model) ?? "anthropic/claude-sonnet-4-6"
        self.openRouterAPIKey = defaults.string(forKey: Keys.apiKey) ?? "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"
    }
}

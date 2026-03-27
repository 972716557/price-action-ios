import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - State

    @Published var stock: StockItem = .defaultStock
    @Published var klines: [KlineData] = []
    @Published var timeframe: KlineTimeframe = .day
    @Published var loading = false
    @Published var loadingAI = false
    @Published var error: String?
    @Published var aiResult: AIAnalysisResult?
    @Published var totalCost: Double = 0
    @Published var marketStatus = MarketTimeService.marketStatus
    @Published var lastUpdate = ""

    // 扫描
    @Published var scanning = false
    @Published var scanProgress: ScanProgress?
    @Published var scanResults: [ScanResult] = []
    @Published var useAIScan = false

    // 冷却
    @Published var aiCooldown: TimeInterval = 0
    @Published var scanCooldown: TimeInterval = 0

    private let aiCooldownDuration: TimeInterval = 10
    private let scanCooldownDuration: TimeInterval = 30

    private var liveTimer: Timer?
    private var statusTimer: Timer?
    private var cooldownTimer: Timer?

    // MARK: - Init

    init() {
        startTimers()
    }

    deinit {
        liveTimer?.invalidate()
        statusTimer?.invalidate()
        cooldownTimer?.invalidate()
    }

    // MARK: - Load K-lines

    func loadKlines(for stock: StockItem? = nil, timeframe: KlineTimeframe? = nil, silent: Bool = false) {
        let s = stock ?? self.stock
        let tf = timeframe ?? self.timeframe
        if let stock = stock { self.stock = stock }
        if let timeframe = timeframe { self.timeframe = timeframe }

        if !silent {
            loading = true
            error = nil
            klines = []
            aiResult = nil
        }

        Task {
            do {
                let count = tf == .sixtyMin ? 200 : 120
                let data = try await StockAPIService.shared.fetchKlineData(symbol: s.symbol, count: count, timeframe: tf)
                guard !data.isEmpty else { throw StockError.emptyData }
                self.klines = data
                self.lastUpdate = Self.timeString()
            } catch {
                if !silent { self.error = error.localizedDescription }
            }
            if !silent { self.loading = false }
        }
    }

    // MARK: - AI 分析

    func runAnalysis() {
        guard !klines.isEmpty, aiCooldown <= 0 else { return }
        loadingAI = true
        error = nil
        aiResult = nil

        Task {
            do {
                let result = try await AIAnalyzerService.shared.analyzeWithAI(
                    klines: klines, stockName: stock.name, stockCode: stock.code
                )
                if let cost = result.tokenUsage?.cost {
                    totalCost += cost
                }
                aiResult = result
                StorageService.shared.saveAnalysisRecord(stock: stock, result: result)
                aiCooldown = aiCooldownDuration
                startCooldownTimer()
            } catch {
                self.error = error.localizedDescription
            }
            loadingAI = false
        }
    }

    // MARK: - 扫描

    func runScan() {
        guard scanCooldown <= 0 else { return }
        scanning = true
        scanResults = []
        scanProgress = nil

        Task {
            do {
                let results = try await StockScanner.shared.scanTopStocks(
                    topN: 3,
                    useAI: useAIScan
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                }
                scanResults = results
                scanCooldown = scanCooldownDuration
                startCooldownTimer()
            } catch {
                self.error = error.localizedDescription
            }
            scanning = false
        }
    }

    func selectFromScan(_ result: ScanResult) {
        loadKlines(for: result.stock)
    }

    // MARK: - Timers

    private func startTimers() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.marketStatus = MarketTimeService.marketStatus
            }
        }

        liveTimer = Timer.scheduledTimer(withTimeInterval: MarketTimeService.liveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, MarketTimeService.isTradingHours else { return }
                self.loadKlines(silent: true)
            }
        }
    }

    private func startCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                if self.aiCooldown > 0 { self.aiCooldown -= 1 }
                if self.scanCooldown > 0 { self.scanCooldown -= 1 }
                if self.aiCooldown <= 0 && self.scanCooldown <= 0 { timer.invalidate() }
            }
        }
    }

    private static func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

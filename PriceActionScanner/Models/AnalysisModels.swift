import Foundation

// MARK: - AI 分析结果

enum TradeSignalType: String, Codable {
    case long
    case short
    case wait
}

struct AIAnalysisResult: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let signal: TradeSignalType
    let confidence: Int
    let marketPhase: String
    let pattern: String
    let reasons: [String]
    let warnings: [String]
    let entryPrice: Double?
    let stopLoss: Double?
    let target: Double?
    let summary: String
    var tokenUsage: TokenUsage?

    struct TokenUsage: Codable {
        let prompt: Int
        let completion: Int
        var cost: Double?
    }

    var signalLabel: String {
        switch signal {
        case .long: return "做多信号"
        case .short: return "做空信号"
        case .wait: return "观望等待"
        }
    }
}

// MARK: - 分析历史记录

struct AnalysisRecord: Codable, Identifiable {
    let id: String
    let stock: StockItem
    let result: AIAnalysisResult
    let timestamp: TimeInterval
}

// MARK: - K线分析

enum Signal: String {
    case bullish, bearish, neutral
}

enum MarketPhase: String {
    case strongUptrend = "strong_uptrend"
    case strongDowntrend = "strong_downtrend"
    case tradingRange = "trading_range"
    case weakTrend = "weak_trend"
}

struct CandleAnalysis {
    let date: String
    let isStrongTrendBar: Bool
    let isBullish: Bool
    let bodyRatio: Double
    let upperWickRatio: Double
    let lowerWickRatio: Double
    let isCloseNearExtreme: Bool
    let isDoji: Bool
    let isOutsideBar: Bool
    let isInsideBar: Bool
    let isReversalBar: Bool
}

struct TrendAnalysis {
    let phase: MarketPhase
    let direction: Signal
    let strength: Int
    let ma20: Double
    let ma5: Double
    let recentHighs: [Double]
    let recentLows: [Double]
}

struct TradeSignal {
    let type: TradeSignalType
    let confidence: Int
    let reasons: [String]
    let warnings: [String]
    let entryPrice: Double?
    let stopLoss: Double?
    let target: Double?
    let pattern: String
}

struct FullAnalysis {
    let stockName: String
    let stockCode: String
    let date: String
    let currentPrice: Double
    let candle: CandleAnalysis
    let trend: TrendAnalysis
    let signal: TradeSignal
    let recentCandles: [CandleAnalysis]
}

// MARK: - 扫描结果

struct ScanResult: Identifiable {
    var id: String { stock.code }
    let stock: StockItem
    let score: Int
    let signal: TradeSignalType
    let pattern: String
    let reasons: [String]
    let lastPrice: Double
    let changePct: Double
    var klineText: String?
    var aiScore: Int?
    var aiReason: String?
}

struct ScanProgress {
    enum Phase { case pool, kline, ai, done }
    let phase: Phase
    let current: Int
    let total: Int
    let message: String
}

// MARK: - AI 模型

struct AIModel: Identifiable {
    let id: String
    let name: String
}

let availableModels: [AIModel] = [
    AIModel(id: "anthropic/claude-sonnet-4-6", name: "Claude Sonnet 4.6"),
    AIModel(id: "anthropic/claude-haiku-4", name: "Claude Haiku 4"),
    AIModel(id: "openai/gpt-4o", name: "GPT-4o"),
    AIModel(id: "openai/gpt-4o-mini", name: "GPT-4o Mini"),
    AIModel(id: "google/gemini-2.0-flash-001", name: "Gemini 2.0 Flash"),
]

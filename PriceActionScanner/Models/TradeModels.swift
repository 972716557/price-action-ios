import Foundation

// MARK: - 市场环境

enum MarketContext: String, CaseIterable, Identifiable {
    case strongTrend = "strong_trend"
    case tradingRange = "trading_range"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strongTrend: return "强趋势 (Strong Trend)"
        case .tradingRange: return "震荡区间 (Trading Range)"
        }
    }
}

// MARK: - 入场尝试

enum EntryAttempt: String, CaseIterable, Identifiable {
    case h1l1 = "H1/L1"
    case h2l2 = "H2/L2"

    var id: String { rawValue }

    var label: String { rawValue }
}

// MARK: - 方向

enum TradeDirection: String, CaseIterable, Identifiable {
    case long
    case short

    var id: String { rawValue }

    var label: String {
        switch self {
        case .long: return "做多"
        case .short: return "做空"
        }
    }
}

// MARK: - 交易表单数据

struct TradeFormData {
    var context: MarketContext?
    var isBreakoutAttempt: Bool = false
    var isStrongTrendBar: Bool = false
    var isCloseNearExtreme: Bool = false
    var entryAttempt: EntryAttempt?
    var hasFollowThrough: Bool = false
    var acceptsRiskRules: Bool = false
    var measureHeight: Double?
    var entryPrice: Double?
    var direction: TradeDirection = .long

    static let initial = TradeFormData()
}

// MARK: - 评估结果

enum Verdict: String {
    case approved
    case rejected
}

struct TradeEvaluation {
    let verdict: Verdict
    let reasons: [String]
    let warnings: [String]
    let stopOrderPrice: Double?
    let targetPrice: Double?
}

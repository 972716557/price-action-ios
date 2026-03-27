import Foundation

// MARK: - K线数据

struct KlineData: Codable, Identifiable {
    var id: String { date }
    let date: String
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double
    let amount: Double

    var isBullish: Bool { close >= open }
    var range: Double { high - low }
    var body: Double { abs(close - open) }
}

// MARK: - K线周期

enum KlineTimeframe: String, CaseIterable, Identifiable {
    case day
    case week
    case sixtyMin = "60min"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "日K"
        case .week: return "周K"
        case .sixtyMin: return "60分钟"
        }
    }

    var apiParam: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .sixtyMin: return "m60"
        }
    }

    var responseKey: String {
        switch self {
        case .day: return "qfqday"
        case .week: return "qfqweek"
        case .sixtyMin: return "qfqm60"
        }
    }

    var fallbackKey: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .sixtyMin: return "m60"
        }
    }
}

// MARK: - 股票

struct StockItem: Codable, Identifiable, Equatable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let market: String
    let symbol: String
    let type: String

    static let defaultStock = StockItem(
        code: "002050",
        name: "三花智控",
        market: "sz",
        symbol: "sz002050",
        type: "GP-A"
    )
}

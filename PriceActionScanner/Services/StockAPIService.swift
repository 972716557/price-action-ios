import Foundation

actor StockAPIService {
    static let shared = StockAPIService()

    private let suggestBase = "https://smartbox.gtimg.cn"
    private let klineBase = "https://web.ifzq.gtimg.cn"

    // MARK: - 搜索股票

    func searchStocks(keyword: String) async throws -> [StockItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let url = URL(string: "\(suggestBase)/s3/?v=2&q=\(encoded)&t=all")!

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        // 解码 Unicode 转义
        let decoded = text.unicodeUnescaped

        guard let match = decoded.range(of: #"v_hint="(.+)""#, options: .regularExpression),
              decoded[match] != "v_hint=\"N\"" else {
            return []
        }

        let hintStart = decoded.index(match.lowerBound, offsetBy: 8)
        let hintEnd = decoded.index(match.upperBound, offsetBy: -1)
        let hintContent = String(decoded[hintStart..<hintEnd])

        var items = hintContent.split(separator: "^").compactMap { item -> StockItem? in
            let parts = item.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { return nil }
            let market = parts[0]
            let code = parts[1]
            let name = parts[2]
            let type = parts[4]
            return StockItem(code: code, name: name, market: market, symbol: "\(market)\(code)", type: type)
        }.filter { s in
            (s.market == "sh" || s.market == "sz") &&
            (s.type.contains("GP-A") || s.type.contains("ETF") || s.type.contains("KCB") || s.type.contains("CYB") || s.type.contains("fund"))
        }

        // 数字搜索时排序
        if trimmed.allSatisfy({ $0.isNumber }) {
            items.sort { a, b in
                let aExact = a.code == trimmed ? 0 : 1
                let bExact = b.code == trimmed ? 0 : 1
                if aExact != bExact { return aExact < bExact }
                let aPrefix = a.code.hasPrefix(trimmed) ? 0 : 1
                let bPrefix = b.code.hasPrefix(trimmed) ? 0 : 1
                return aPrefix < bPrefix
            }
        }

        return items
    }

    // MARK: - 获取K线数据

    func fetchKlineData(
        symbol: String,
        count: Int = 120,
        timeframe: KlineTimeframe = .day
    ) async throws -> [KlineData] {
        let tf = timeframe.apiParam
        let url = URL(string: "\(klineBase)/appstock/app/fqkline/get?param=\(symbol),\(tf),,,\(count),qfq")!

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataDict = json["data"] as? [String: Any],
              let stockData = dataDict[symbol] as? [String: Any] else {
            throw StockError.fetchFailed("获取K线数据失败")
        }

        let klines: [[Any]] = (stockData[timeframe.responseKey] as? [[Any]])
            ?? (stockData[timeframe.fallbackKey] as? [[Any]])
            ?? []

        guard !klines.isEmpty else {
            throw StockError.emptyData
        }

        return klines.compactMap { k -> KlineData? in
            guard k.count >= 6,
                  let date = k[0] as? String else { return nil }

            func toDouble(_ val: Any) -> Double {
                if let d = val as? Double { return d }
                if let s = val as? String { return Double(s) ?? 0 }
                if let n = val as? NSNumber { return n.doubleValue }
                return 0
            }

            return KlineData(
                date: date,
                open: toDouble(k[1]),
                close: toDouble(k[2]),
                high: toDouble(k[3]),
                low: toDouble(k[4]),
                volume: toDouble(k[5]),
                amount: 0
            )
        }
    }

    // MARK: - 获取股票池 (新浪)

    func fetchStockPool(size: Int = 100) async throws -> [StockItem] {
        let urlStr = "https://vip.stock.finance.sina.com.cn/quotes_service/api/json_v2.php/Market_Center.getHQNodeData?page=1&num=\(size)&sort=amount&asc=0&node=hs_a&symbol=&_s_r_a=init"
        let url = URL(string: urlStr)!

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw StockError.fetchFailed("获取股票池失败")
        }

        return list.compactMap { item -> StockItem? in
            guard let code = item["code"] as? String,
                  let name = item["name"] as? String,
                  let symbolStr = item["symbol"] as? String else { return nil }

            // 过滤
            if name.contains("ST") || name.contains("st") { return nil }
            if code.hasPrefix("300") || code.hasPrefix("301") { return nil }
            if code.hasPrefix("688") || code.hasPrefix("689") { return nil }
            if code.hasPrefix("8") || code.hasPrefix("4") { return nil }

            let market = symbolStr.hasPrefix("sh") ? "sh" : "sz"
            return StockItem(code: code, name: name, market: market, symbol: symbolStr, type: "GP-A")
        }
    }
}

// MARK: - Error

enum StockError: LocalizedError {
    case fetchFailed(String)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let msg): return msg
        case .emptyData: return "K线数据为空"
        }
    }
}

// MARK: - Unicode helper

private extension String {
    var unicodeUnescaped: String {
        var result = self
        let pattern = try! NSRegularExpression(pattern: "\\\\u([0-9a-fA-F]{4})")
        let matches = pattern.matches(in: self, range: NSRange(startIndex..., in: self))
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: self),
                  let codePoint = UInt32(self[range], radix: 16),
                  let scalar = Unicode.Scalar(codePoint) else { continue }
            let fullRange = Range(match.range, in: result)!
            result.replaceSubrange(fullRange, with: String(scalar))
        }
        return result
    }
}

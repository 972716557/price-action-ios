import Foundation

actor StockScanner {
    static let shared = StockScanner()

    // MARK: - H2/L2 检测

    private func detectH2L2(klines: [KlineData], signal: TradeSignalType) -> (detected: Bool, quality: String) {
        guard klines.count >= 10 else { return (false, "weak") }
        let recent = Array(klines.suffix(15))
        var pullbacks: [(index: Int, depth: Double)] = []

        if signal == .long {
            for i in 2..<(recent.count - 1) {
                if recent[i].low < recent[i - 1].low && recent[i].low < recent[i + 1].low {
                    let recentHigh = recent[max(0, i - 5)..<i].map(\.high).max() ?? 0
                    let depth = recentHigh > 0 ? (recentHigh - recent[i].low) / recentHigh : 0
                    if depth > 0.01 {
                        pullbacks.append((i, depth))
                    }
                }
            }
        } else {
            for i in 2..<(recent.count - 1) {
                if recent[i].high > recent[i - 1].high && recent[i].high > recent[i + 1].high {
                    let recentLow = recent[max(0, i - 5)..<i].map(\.low).min() ?? 0
                    let depth = recentLow > 0 ? (recent[i].high - recentLow) / recentLow : 0
                    if depth > 0.01 {
                        pullbacks.append((i, depth))
                    }
                }
            }
        }

        guard pullbacks.count >= 2 else { return (false, "weak") }

        let lastTwo = Array(pullbacks.suffix(2))
        let quality = lastTwo[1].depth < lastTwo[0].depth ? "strong" : "medium"
        return (true, quality)
    }

    // MARK: - 评分

    private func scoreStock(klines: [KlineData]) -> (score: Int, signal: TradeSignalType, pattern: String, reasons: [String])? {
        guard klines.count >= 25 else { return nil }

        var reasons = [String]()
        var score = 0
        var signal: TradeSignalType = .long
        var patterns = [String]()

        let last = klines.last!
        let prev = klines[klines.count - 2]

        let range = last.high - last.low
        let body = abs(last.close - last.open)
        let bodyRatio = range > 0 ? body / range : 0
        let isBullish = last.close >= last.open
        let upperWick = isBullish ? last.high - last.close : last.high - last.open
        let lowerWick = isBullish ? last.open - last.low : last.close - last.low
        let upperWickRatio = range > 0 ? upperWick / range : 0
        let lowerWickRatio = range > 0 ? lowerWick / range : 0

        let closes = klines.map(\.close)
        let ma5 = avg(Array(closes.suffix(5)))
        let ma20 = avg(Array(closes.suffix(20)))
        let ma60 = klines.count >= 60 ? avg(Array(closes.suffix(60))) : ma20

        let bullishMA = last.close > ma5 && ma5 > ma20
        let bearishMA = last.close < ma5 && ma5 < ma20

        if bullishMA {
            score += 15; reasons.append("均线多头排列 (MA5>MA20)"); signal = .long
        } else if bearishMA {
            score += 15; reasons.append("均线空头排列 (MA5<MA20)"); signal = .short
        }

        let isStrongBar = bodyRatio >= 0.65 && max(upperWickRatio, lowerWickRatio) < 0.2
        let isCloseNearExtreme = isBullish ? upperWickRatio < 0.15 : lowerWickRatio < 0.15

        if isStrongBar {
            score += 20; reasons.append("最新K线为强趋势K线（实体饱满）"); patterns.append("强趋势K线")
            signal = isBullish ? .long : .short
        }

        if isCloseNearExtreme && isStrongBar {
            score += 10; reasons.append("收盘接近极值（光头/光脚）")
        }

        let prevBody = abs(prev.close - prev.open)
        let prevBullish = prev.close >= prev.open
        if isStrongBar && isBullish && prevBullish && prevBody > 0 {
            score += 15; reasons.append("连续两根阳线（跟随确认）"); patterns.append("Follow-Through")
        } else if isStrongBar && !isBullish && !prevBullish && prevBody > 0 {
            score += 15; reasons.append("连续两根阴线（跟随确认）"); patterns.append("Follow-Through")
        }

        let h2l2 = detectH2L2(klines: klines, signal: signal)
        if h2l2.detected {
            let bonus = h2l2.quality == "strong" ? 25 : h2l2.quality == "medium" ? 20 : 15
            score += bonus
            reasons.append(signal == .long
                ? "H2 二次回调入场信号 (\(h2l2.quality))"
                : "L2 二次反弹入场信号 (\(h2l2.quality))")
            patterns.append(signal == .long ? "H2" : "L2")
        }

        let avgVol = avg(klines.suffix(20).map(\.volume))
        if last.volume > avgVol * 1.5 {
            score += 10; reasons.append("成交量放大（超过20日均量1.5倍）")
        }

        if (signal == .long && last.close > ma60) || (signal == .short && last.close < ma60) {
            score += 10; reasons.append("价格与长期趋势(MA60)方向一致")
        }

        guard score >= 30 else { return nil }

        return (min(100, score), signal, patterns.joined(separator: " + ").isEmpty ? "趋势延续" : patterns.joined(separator: " + "), reasons)
    }

    private func avg(_ arr: [Double]) -> Double {
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0, +) / Double(arr.count)
    }

    // MARK: - 扫描入口

    func scanTopStocks(
        topN: Int = 3,
        useAI: Bool = false,
        onProgress: @Sendable (ScanProgress) -> Void
    ) async throws -> [ScanResult] {
        onProgress(ScanProgress(phase: .pool, current: 0, total: 0, message: "获取活跃股票池..."))
        let pool = try await StockAPIService.shared.fetchStockPool(size: 100)
        guard !pool.isEmpty else { throw StockError.fetchFailed("获取股票池失败") }

        onProgress(ScanProgress(phase: .pool, current: pool.count, total: pool.count, message: "获取到 \(pool.count) 只股票"))

        var results = [ScanResult]()
        let concurrency = 5
        var completed = 0

        for batchStart in stride(from: 0, to: pool.count, by: concurrency) {
            let batch = Array(pool[batchStart..<min(batchStart + concurrency, pool.count)])
            await withTaskGroup(of: ScanResult?.self) { group in
                for stock in batch {
                    group.addTask {
                        do {
                            let klines = try await StockAPIService.shared.fetchKlineData(symbol: stock.symbol, count: 60)
                            guard klines.count >= 25 else { return nil }
                            guard let scoring = await self.scoreStock(klines: klines) else { return nil }

                            let last = klines.last!
                            let prev = klines[klines.count - 2]
                            let changePct = prev.close > 0 ? ((last.close - prev.close) / prev.close) * 100 : 0

                            let recent5 = klines.suffix(5)
                            let klineText = recent5.map { k in
                                "\(k.date) 开\(k.open) 收\(k.close) 高\(k.high) 低\(k.low) 量\(Int(k.volume))"
                            }.joined(separator: "\n")

                            return ScanResult(
                                stock: stock, score: scoring.score, signal: scoring.signal,
                                pattern: scoring.pattern, reasons: scoring.reasons,
                                lastPrice: last.close, changePct: changePct, klineText: klineText
                            )
                        } catch {
                            return nil
                        }
                    }
                }
                for await result in group {
                    completed += 1
                    if let result = result {
                        results.append(result)
                    }
                    onProgress(ScanProgress(
                        phase: .kline, current: completed, total: pool.count,
                        message: "分析中 \(completed)/\(pool.count)"
                    ))
                }
            }
        }

        results.sort { $0.score > $1.score }

        // AI 精选
        if useAI && !results.isEmpty {
            onProgress(ScanProgress(phase: .ai, current: 0, total: 1, message: "AI 正在从候选中精选..."))
            do {
                let top10 = Array(results.prefix(10))
                let candidates = top10.map {
                    (name: $0.stock.name, code: $0.stock.code, score: $0.score,
                     signal: $0.signal.rawValue, pattern: $0.pattern, reasons: $0.reasons,
                     klineText: $0.klineText ?? "", lastPrice: $0.lastPrice, changePct: $0.changePct)
                }
                let aiPicks = try await AIAnalyzerService.shared.aiSelectTopStocks(candidates: candidates)

                var aiResults = [ScanResult]()
                for pick in aiPicks {
                    if var found = results.first(where: { $0.stock.code == pick.code }) {
                        found.aiScore = pick.aiScore
                        found.aiReason = pick.reason
                        aiResults.append(found)
                    }
                }

                onProgress(ScanProgress(phase: .done, current: 1, total: 1, message: "AI 精选完成"))
                return aiResults.isEmpty ? Array(results.prefix(topN)) : Array(aiResults.prefix(topN))
            } catch {
                // AI 失败回退
            }
        }

        onProgress(ScanProgress(
            phase: .done, current: pool.count, total: pool.count,
            message: "扫描完成，找到 \(results.count) 只符合条件的股票"
        ))

        return Array(results.prefix(topN))
    }
}

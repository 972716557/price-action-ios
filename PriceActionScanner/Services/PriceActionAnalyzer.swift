import Foundation

enum PriceActionAnalyzer {

    // MARK: - 分析入口

    static func analyzeStock(klines: [KlineData], stockName: String, stockCode: String) -> FullAnalysis {
        precondition(klines.count >= 25, "K线数据不足，至少需要25根K线")

        let candleAnalyses = klines.enumerated().map { i, k in
            analyzeCandle(k, prev: i > 0 ? klines[i - 1] : nil)
        }
        let trend = analyzeTrend(klines: klines)
        let signal = generateSignal(klines: klines, trend: trend, candles: candleAnalyses)

        return FullAnalysis(
            stockName: stockName,
            stockCode: stockCode,
            date: klines.last!.date,
            currentPrice: klines.last!.close,
            candle: candleAnalyses.last!,
            trend: trend,
            signal: signal,
            recentCandles: Array(candleAnalyses.suffix(10))
        )
    }

    // MARK: - K线分析

    private static func analyzeCandle(_ k: KlineData, prev: KlineData?) -> CandleAnalysis {
        let range = k.high - k.low
        let body = abs(k.close - k.open)
        let bodyRatio = range > 0 ? body / range : 0
        let isBullish = k.close >= k.open

        let upperWick = isBullish ? k.high - k.close : k.high - k.open
        let lowerWick = isBullish ? k.open - k.low : k.close - k.low
        let upperWickRatio = range > 0 ? upperWick / range : 0
        let lowerWickRatio = range > 0 ? lowerWick / range : 0

        let isStrongTrendBar = bodyRatio >= 0.65 && max(upperWickRatio, lowerWickRatio) < 0.2
        let isCloseNearExtreme = isBullish ? upperWickRatio < 0.15 : lowerWickRatio < 0.15
        let isDoji = bodyRatio < 0.15

        var isOutsideBar = false
        var isInsideBar = false
        if let prev = prev {
            isOutsideBar = k.high > prev.high && k.low < prev.low
            isInsideBar = k.high <= prev.high && k.low >= prev.low
        }

        let isReversalBar = !isStrongTrendBar && (
            (upperWickRatio > 0.5 && k.close < k.open) ||
            (lowerWickRatio > 0.5 && k.close > k.open)
        )

        return CandleAnalysis(
            date: k.date, isStrongTrendBar: isStrongTrendBar, isBullish: isBullish,
            bodyRatio: bodyRatio, upperWickRatio: upperWickRatio, lowerWickRatio: lowerWickRatio,
            isCloseNearExtreme: isCloseNearExtreme, isDoji: isDoji,
            isOutsideBar: isOutsideBar, isInsideBar: isInsideBar, isReversalBar: isReversalBar
        )
    }

    // MARK: - 均线

    private static func calcMA(_ klines: [KlineData], period: Int) -> [Double] {
        var result = [Double]()
        for i in 0..<klines.count {
            if i < period - 1 {
                result.append(.nan)
            } else {
                let sum = klines[(i - period + 1)...i].reduce(0.0) { $0 + $1.close }
                result.append((sum / Double(period) * 10000).rounded() / 10000)
            }
        }
        return result
    }

    // MARK: - 趋势分析

    private static func analyzeTrend(klines: [KlineData]) -> TrendAnalysis {
        let ma5 = calcMA(klines, period: 5)
        let ma20 = calcMA(klines, period: 20)
        let last = klines.count - 1
        let currentMa5 = ma5[last]
        let currentMa20 = ma20[last]
        let currentPrice = klines[last].close

        let recent = Array(klines.suffix(10))
        let recentHighs = recent.map(\.high)
        let recentLows = recent.map(\.low)

        var higherHighs = 0
        var lowerLows = 0
        for i in 1..<recent.count {
            if recent[i].high > recent[i - 1].high { higherHighs += 1 }
            if recent[i].low < recent[i - 1].low { lowerLows += 1 }
        }

        let bullishBias = Double(higherHighs) / Double(recent.count - 1)
        let bearishBias = Double(lowerLows) / Double(recent.count - 1)

        let phase: MarketPhase
        let direction: Signal
        let strength: Int

        if bullishBias > 0.6 && currentPrice > currentMa20 {
            phase = .strongUptrend; direction = .bullish; strength = Int((bullishBias * 100).rounded())
        } else if bearishBias > 0.6 && currentPrice < currentMa20 {
            phase = .strongDowntrend; direction = .bearish; strength = Int((bearishBias * 100).rounded())
        } else if bullishBias > 0.4 || bearishBias > 0.4 {
            phase = .weakTrend
            direction = bullishBias > bearishBias ? .bullish : .bearish
            strength = Int((max(bullishBias, bearishBias) * 60).rounded())
        } else {
            phase = .tradingRange; direction = .neutral; strength = 20
        }

        return TrendAnalysis(
            phase: phase, direction: direction, strength: strength,
            ma20: currentMa20, ma5: currentMa5,
            recentHighs: recentHighs, recentLows: recentLows
        )
    }

    // MARK: - 信号生成

    private static func generateSignal(
        klines: [KlineData], trend: TrendAnalysis, candles: [CandleAnalysis]
    ) -> TradeSignal {
        var reasons = [String]()
        var warnings = [String]()
        let last = klines.count - 1
        let current = candles.last!
        let prev = candles.count > 1 ? candles[candles.count - 2] : nil
        let currentK = klines[last]
        var confidence = 0
        var pattern = ""
        var type: TradeSignalType = .wait
        var entryPrice: Double?
        var stopLoss: Double?
        var target: Double?

        let recent5 = Array(candles.suffix(5))
        let recent5K = Array(klines.suffix(5))
        let hasTwoPullbacks = checkSecondEntry(candles: recent5, klines: recent5K)

        if trend.phase == .strongUptrend {
            reasons.append("市场处于强上升趋势")
            if current.isStrongTrendBar && current.isBullish && current.isCloseNearExtreme {
                confidence += 40; pattern = "强势多头趋势K线"; type = .long
                reasons.append("当前K线为强势多头趋势K线")
            }
            if hasTwoPullbacks == .bullish {
                confidence += 30; pattern = pattern.isEmpty ? "H2二次入场" : pattern + " + H2"; type = .long
                reasons.append("检测到H2二次入场信号")
            }
            if let prev = prev, prev.isStrongTrendBar && prev.isBullish {
                confidence += 15; reasons.append("前一根也是强势多头K线（跟随确认）")
            }
            if currentK.close > trend.ma5 && trend.ma5 > trend.ma20 {
                confidence += 10; reasons.append("均线多头排列")
            }
        }

        if trend.phase == .strongDowntrend {
            reasons.append("市场处于强下降趋势")
            if current.isStrongTrendBar && !current.isBullish && current.isCloseNearExtreme {
                confidence += 40; pattern = "强势空头趋势K线"; type = .short
                reasons.append("当前K线为强势空头趋势K线")
            }
            if hasTwoPullbacks == .bearish {
                confidence += 30; pattern = pattern.isEmpty ? "L2二次入场" : pattern + " + L2"; type = .short
                reasons.append("检测到L2二次入场信号")
            }
            if let prev = prev, prev.isStrongTrendBar && !prev.isBullish {
                confidence += 15; reasons.append("前一根也是强势空头K线")
            }
        }

        if trend.phase == .tradingRange {
            reasons.append("市场处于震荡区间")
            warnings.append("震荡区间中80%的突破会失败，建议高抛低吸")
            let rangeHigh = trend.recentHighs.max() ?? 0
            let rangeLow = trend.recentLows.min() ?? 0
            let rangeSize = rangeHigh - rangeLow
            if currentK.close < rangeLow + rangeSize * 0.3 && current.isBullish && current.isReversalBar {
                confidence += 35; pattern = "区间底部反转"; type = .long
                reasons.append("价格接近区间底部，出现看涨反转K线")
            }
            if currentK.close > rangeHigh - rangeSize * 0.3 && !current.isBullish && current.isReversalBar {
                confidence += 35; pattern = "区间顶部反转"; type = .short
                reasons.append("价格接近区间顶部，出现看跌反转K线")
            }
        }

        if trend.phase == .weakTrend {
            reasons.append("市场趋势较弱，方向不明确")
            warnings.append("弱趋势环境，建议减小仓位或观望")
            confidence = max(0, confidence - 15)
        }

        if current.isDoji {
            warnings.append("当前K线为十字星/Doji，市场犹豫不决")
            confidence = max(0, confidence - 10)
        }

        if !current.isStrongTrendBar && type != .wait {
            warnings.append("信号K线实体不够饱满")
        }

        if type != .wait {
            let recent20 = Array(klines.suffix(20))
            let recentRange = (recent20.map(\.high).max() ?? 0) - (recent20.map(\.low).min() ?? 0)
            let measureHeight = (recentRange * 0.5 * 100).rounded() / 100
            if type == .long {
                entryPrice = currentK.close
                stopLoss = ((currentK.low - recentRange * 0.1) * 100).rounded() / 100
                target = ((currentK.close + measureHeight) * 100).rounded() / 100
            } else {
                entryPrice = currentK.close
                stopLoss = ((currentK.high + recentRange * 0.1) * 100).rounded() / 100
                target = ((currentK.close - measureHeight) * 100).rounded() / 100
            }
        }

        if type == .wait && pattern.isEmpty {
            pattern = "暂无明确形态"
            reasons.append("当前未检测到符合Al Brooks标准的高概率入场信号")
        }

        confidence = min(100, max(0, confidence))
        return TradeSignal(type: type, confidence: confidence, reasons: reasons, warnings: warnings,
                           entryPrice: entryPrice, stopLoss: stopLoss, target: target, pattern: pattern)
    }

    private static func checkSecondEntry(candles: [CandleAnalysis], klines: [KlineData]) -> Signal? {
        guard candles.count >= 4 else { return nil }
        var pullbackLows = 0
        var pullbackHighs = 0
        for i in 1..<(candles.count - 1) {
            if klines[i].low < klines[i - 1].low && klines[i].low < klines[i + 1].low { pullbackLows += 1 }
            if klines[i].high > klines[i - 1].high && klines[i].high > klines[i + 1].high { pullbackHighs += 1 }
        }
        if pullbackLows >= 2 && candles.last!.isBullish { return .bullish }
        if pullbackHighs >= 2 && !candles.last!.isBullish { return .bearish }
        return nil
    }
}

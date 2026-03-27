import SwiftUI

struct CandlestickChartView: View {
    let klines: [KlineData]
    let aiResult: AIAnalysisResult?

    @State private var selectedIndex: Int?
    @State private var scrollOffset: Int = 0       // 从最右侧往左偏移的K线数
    @State private var dragAccumulator: CGFloat = 0 // 拖拽累积量

    private let maxVisible = 60

    private var visibleWindow: (start: Int, end: Int) {
        let total = klines.count
        let end = max(0, total - scrollOffset)
        let start = max(0, end - maxVisible)
        return (start, end)
    }

    private var visibleKlines: [KlineData] {
        let w = visibleWindow
        guard w.start < w.end else { return [] }
        return Array(klines[w.start..<w.end])
    }

    private var visibleCount: Int { visibleKlines.count }

    private var priceRange: (min: Double, max: Double) {
        let highs = visibleKlines.map(\.high)
        let lows = visibleKlines.map(\.low)
        let minPrice = (lows.min() ?? 0) * 0.998
        let maxPrice = (highs.max() ?? 0) * 1.002
        return (minPrice, maxPrice)
    }

    // 计算MA（基于全量数据，取可见窗口段）
    private func calcMA(_ period: Int) -> [Double?] {
        let w = visibleWindow
        var result: [Double?] = []
        for i in w.start..<w.end {
            if i < period - 1 {
                result.append(nil)
            } else {
                let slice = klines[(i - period + 1)...i]
                let avg = slice.map(\.close).reduce(0, +) / Double(period)
                result.append(avg)
            }
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let rightPadding: CGFloat = 50
            let bottomPadding: CGFloat = 30
            let volumeHeight: CGFloat = 40
            let chartHeight = geo.size.height - bottomPadding - volumeHeight - 4
            let width = geo.size.width - rightPadding
            let candleWidth = visibleCount > 0 ? width / CGFloat(visibleCount) : 1
            let bodyWidth = max(1, candleWidth * 0.7)
            let range = priceRange

            ZStack(alignment: .topLeading) {
                // 背景网格
                gridLines(height: chartHeight, width: width, range: range)

                // MA 均线
                maLines(width: width, height: chartHeight, range: range, candleWidth: candleWidth)

                // K线
                candlesCanvas(
                    width: width,
                    height: chartHeight,
                    candleWidth: candleWidth,
                    bodyWidth: bodyWidth,
                    range: range
                )

                // 成交量
                volumeBars(width: width, chartHeight: chartHeight, volumeHeight: volumeHeight, candleWidth: candleWidth)

                // AI 标线
                if let ai = aiResult {
                    aiLines(ai: ai, width: width, height: chartHeight, range: range)
                }

                // 价格轴
                priceAxis(height: chartHeight, range: range, x: width)

                // 选中十字线 + 提示
                if let idx = selectedIndex, idx >= 0, idx < visibleKlines.count {
                    crosshair(index: idx, candleWidth: candleWidth, chartHeight: chartHeight, width: width, range: range)
                    selectedTooltip(kline: visibleKlines[idx], geo: geo)
                }

                // 滚动位置指示
                if scrollOffset > 0 {
                    scrollIndicator
                }
            }
            .contentShape(Rectangle())
            .gesture(chartGesture(candleWidth: candleWidth))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .onChange(of: klines.count) { _, _ in
            scrollOffset = 0
        }
    }

    // MARK: - Gesture

    private func chartGesture(candleWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let translation = value.translation.width
                let startX = value.startLocation.x

                // 判断是横向拖拽（滚动）还是点按（十字线）
                let isHorizontalDrag = abs(value.translation.width) > 8

                if isHorizontalDrag {
                    // 横向拖拽 → 滚动K线
                    selectedIndex = nil
                    let delta = translation - dragAccumulator
                    let candlesMoved = Int(delta / candleWidth)
                    if candlesMoved != 0 {
                        dragAccumulator += CGFloat(candlesMoved) * candleWidth
                        let maxOffset = max(0, klines.count - maxVisible)
                        // 向右拖 → 看更早的数据 → offset 增加
                        scrollOffset = min(maxOffset, max(0, scrollOffset - candlesMoved))
                    }
                } else {
                    // 点按/微移 → 十字线
                    let idx = Int(startX / candleWidth)
                    if idx >= 0 && idx < visibleCount {
                        selectedIndex = idx
                    }
                }
            }
            .onEnded { _ in
                dragAccumulator = 0
                selectedIndex = nil
            }
    }

    // MARK: - Scroll Indicator

    private var scrollIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.system(size: 8))
            Text("左滑返回最新")
                .font(.system(size: 9))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 54)
        .padding(.bottom, 4)
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollOffset = 0
            }
        }
    }

    // MARK: - Crosshair

    private func crosshair(index: Int, candleWidth: CGFloat, chartHeight: CGFloat, width: CGFloat, range: (min: Double, max: Double)) -> some View {
        let x = CGFloat(index) * candleWidth + candleWidth / 2
        let kline = visibleKlines[index]
        let priceSpan = range.max - range.min
        let y = priceSpan > 0 ? CGFloat((range.max - kline.close) / priceSpan) * chartHeight : 0

        return ZStack {
            // 竖线
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: chartHeight))
            }
            .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // 横线
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // 价格标签
            Text(String(format: "%.2f", kline.close))
                .font(.system(size: 9)).foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.indigo, in: RoundedRectangle(cornerRadius: 3))
                .position(x: width + 25, y: y)
        }
    }

    // MARK: - Grid

    private func gridLines(height: CGFloat, width: CGFloat, range: (min: Double, max: Double)) -> some View {
        Canvas { context, _ in
            let steps = 4
            for i in 0...steps {
                let y = CGFloat(i) / CGFloat(steps) * height
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
            }
        }
        .frame(height: height)
    }

    // MARK: - MA Lines

    private func maLines(width: CGFloat, height: CGFloat, range: (min: Double, max: Double), candleWidth: CGFloat) -> some View {
        let priceSpan = range.max - range.min
        let ma5 = calcMA(5)
        let ma20 = calcMA(20)

        return Canvas { context, _ in
            guard priceSpan > 0 else { return }

            func drawMA(_ values: [Double?], color: Color) {
                var path = Path()
                var started = false
                for (i, val) in values.enumerated() {
                    guard let v = val, v >= range.min, v <= range.max else { continue }
                    let x = CGFloat(i) * candleWidth + candleWidth / 2
                    let y = CGFloat((range.max - v) / priceSpan) * height
                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(color), lineWidth: 1)
            }

            drawMA(ma5, color: .yellow.opacity(0.8))
            drawMA(ma20, color: .cyan.opacity(0.8))
        }
        .frame(height: height)
    }

    // MARK: - Candles (Canvas)

    private func candlesCanvas(width: CGFloat, height: CGFloat, candleWidth: CGFloat, bodyWidth: CGFloat, range: (min: Double, max: Double)) -> some View {
        let priceSpan = range.max - range.min
        let data = visibleKlines

        return Canvas { context, _ in
            guard priceSpan > 0 else { return }
            for (index, kline) in data.enumerated() {
                let x = CGFloat(index) * candleWidth + candleWidth / 2
                let isUp = kline.close >= kline.open
                let color: Color = isUp ? .red : .green

                let highY = CGFloat((range.max - kline.high) / priceSpan) * height
                let lowY = CGFloat((range.max - kline.low) / priceSpan) * height
                let openY = CGFloat((range.max - kline.open) / priceSpan) * height
                let closeY = CGFloat((range.max - kline.close) / priceSpan) * height
                let bodyTop = min(openY, closeY)
                let bodyH = max(1, abs(closeY - openY))

                // 影线
                let wickRect = CGRect(x: x - 0.5, y: highY, width: 1, height: lowY - highY)
                context.fill(Path(wickRect), with: .color(color))

                // 实体
                let bodyRect = CGRect(x: x - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: bodyH)
                context.fill(Path(bodyRect), with: .color(color))
            }
        }
        .frame(height: height)
    }

    // MARK: - Volume Bars

    private func volumeBars(width: CGFloat, chartHeight: CGFloat, volumeHeight: CGFloat, candleWidth: CGFloat) -> some View {
        let maxVol = visibleKlines.map(\.volume).max() ?? 1
        let bodyWidth = max(1, candleWidth * 0.7)

        return Canvas { context, _ in
            guard maxVol > 0 else { return }
            for (i, kline) in visibleKlines.enumerated() {
                let x = CGFloat(i) * candleWidth + candleWidth / 2
                let barHeight = CGFloat(kline.volume / maxVol) * volumeHeight
                let y = chartHeight + 4 + volumeHeight - barHeight
                let isUp = kline.close >= kline.open
                let color: Color = isUp ? .red.opacity(0.4) : .green.opacity(0.4)

                let rect = CGRect(
                    x: x - bodyWidth / 2,
                    y: y,
                    width: bodyWidth,
                    height: barHeight
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
        .frame(height: chartHeight + 4 + volumeHeight)
    }

    // MARK: - AI Lines

    @ViewBuilder
    private func aiLines(ai: AIAnalysisResult, width: CGFloat, height: CGFloat, range: (min: Double, max: Double)) -> some View {
        let priceSpan = range.max - range.min
        if priceSpan > 0 {
            if let entry = ai.entryPrice {
                priceLine(price: entry, range: range, height: height, width: width, color: .white, label: "入场")
            }
            if let stop = ai.stopLoss {
                priceLine(price: stop, range: range, height: height, width: width, color: .red, label: "止损")
            }
            if let target = ai.target {
                priceLine(price: target, range: range, height: height, width: width, color: .green, label: "目标")
            }
        }
    }

    private func priceLine(price: Double, range: (min: Double, max: Double), height: CGFloat, width: CGFloat, color: Color, label: String) -> some View {
        let priceSpan = range.max - range.min
        let y = CGFloat((range.max - price) / priceSpan) * height

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            Text("\(label) \(String(format: "%.2f", price))")
                .font(.system(size: 9)).foregroundStyle(color)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                .position(x: 50, y: y - 8)
        }
    }

    // MARK: - Price Axis

    private func priceAxis(height: CGFloat, range: (min: Double, max: Double), x: CGFloat) -> some View {
        let steps = 4
        let priceSpan = range.max - range.min

        return ForEach(0...steps, id: \.self) { i in
            let price = range.max - (priceSpan * Double(i) / Double(steps))
            let y = CGFloat(i) / CGFloat(steps) * height

            Text(String(format: "%.2f", price))
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .position(x: x + 25, y: y)
        }
    }

    // MARK: - Tooltip

    @ViewBuilder
    private func selectedTooltip(kline: KlineData, geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kline.date).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("开\(String(format: "%.2f", kline.open))")
                Text("收\(String(format: "%.2f", kline.close))")
                Text("高\(String(format: "%.2f", kline.high))")
                Text("低\(String(format: "%.2f", kline.low))")
            }
            .font(.system(size: 10)).monospacedDigit()
            Text("量 \(Int(kline.volume))").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .position(x: geo.size.width / 2, y: 30)
    }
}

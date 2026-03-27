import SwiftUI

struct CandlestickChartView: View {
    let klines: [KlineData]
    let aiResult: AIAnalysisResult?

    @State private var selectedIndex: Int?
    @State private var dragOffset: CGFloat = 0

    // 显示最近60根K线
    private var visibleCount: Int { min(60, klines.count) }
    private var visibleKlines: [KlineData] {
        Array(klines.suffix(visibleCount))
    }

    private var priceRange: (min: Double, max: Double) {
        let highs = visibleKlines.map(\.high)
        let lows = visibleKlines.map(\.low)
        let minPrice = (lows.min() ?? 0) * 0.998
        let maxPrice = (highs.max() ?? 0) * 1.002
        return (minPrice, maxPrice)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - 50 // 右侧价格轴留空
            let height = geo.size.height - 30 // 底部日期留空
            let candleWidth = width / CGFloat(visibleCount)
            let bodyWidth = max(1, candleWidth * 0.7)
            let range = priceRange

            ZStack(alignment: .topLeading) {
                // 背景网格
                gridLines(height: height, width: width, range: range)

                // K线
                ForEach(Array(visibleKlines.enumerated()), id: \.offset) { index, kline in
                    candleView(
                        kline: kline,
                        index: index,
                        candleWidth: candleWidth,
                        bodyWidth: bodyWidth,
                        height: height,
                        range: range
                    )
                }

                // AI 标线
                if let ai = aiResult {
                    aiLines(ai: ai, width: width, height: height, range: range)
                }

                // 价格轴
                priceAxis(height: height, range: range, x: width)

                // 选中提示
                if let idx = selectedIndex, idx < visibleKlines.count {
                    selectedTooltip(kline: visibleKlines[idx], geo: geo)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x
                        let idx = Int(x / candleWidth)
                        if idx >= 0 && idx < visibleKlines.count {
                            selectedIndex = idx
                        }
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
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

    // MARK: - Candle

    private func candleView(
        kline: KlineData, index: Int, candleWidth: CGFloat, bodyWidth: CGFloat,
        height: CGFloat, range: (min: Double, max: Double)
    ) -> some View {
        let priceSpan = range.max - range.min
        guard priceSpan > 0 else { return AnyView(EmptyView()) }

        let x = CGFloat(index) * candleWidth + candleWidth / 2
        let isUp = kline.close >= kline.open
        let color: Color = isUp ? .red : .green

        let highY = CGFloat((range.max - kline.high) / priceSpan) * height
        let lowY = CGFloat((range.max - kline.low) / priceSpan) * height
        let openY = CGFloat((range.max - kline.open) / priceSpan) * height
        let closeY = CGFloat((range.max - kline.close) / priceSpan) * height

        let bodyTop = min(openY, closeY)
        let bodyHeight = max(1, abs(closeY - openY))

        return AnyView(
            ZStack {
                // 影线
                Rectangle()
                    .fill(color)
                    .frame(width: 1, height: lowY - highY)
                    .position(x: x, y: (highY + lowY) / 2)

                // 实体
                Rectangle()
                    .fill(isUp ? color : color)
                    .frame(width: bodyWidth, height: bodyHeight)
                    .position(x: x, y: bodyTop + bodyHeight / 2)
            }
        )
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

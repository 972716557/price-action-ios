import SwiftUI

struct TradeFormView: View {
    @State private var formData = TradeFormData.initial
    @State private var evaluation: TradeEvaluation?
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Step indicator
                    stepIndicator

                    // Current step content
                    Group {
                        switch step {
                        case 0: step1MarketContext
                        case 1: step2SignalBar
                        case 2: step3Entry
                        case 3: step4Risk
                        default: EmptyView()
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Navigation buttons
                    navigationButtons

                    // Result
                    if let eval = evaluation {
                        resultView(eval)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("手动评估")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.indigo : i < step ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                if i < totalSteps - 1 {
                    Rectangle()
                        .fill(i < step ? Color.green : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Step 1: Market Context

    private var step1MarketContext: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 1: 市场环境").font(.headline)
            Text("当前市场处于什么状态？").font(.caption).foregroundStyle(.secondary)

            ForEach(MarketContext.allCases) { ctx in
                Button {
                    formData.context = ctx
                } label: {
                    HStack {
                        Image(systemName: formData.context == ctx ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(formData.context == ctx ? .indigo : .secondary)
                        Text(ctx.label).foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(formData.context == ctx ? Color.indigo.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if formData.context == .tradingRange {
                Toggle("是否为突破尝试？", isOn: $formData.isBreakoutAttempt)
                    .font(.subheadline)
            }

            // 方向
            Picker("方向", selection: $formData.direction) {
                ForEach(TradeDirection.allCases) { dir in
                    Text(dir.label).tag(dir)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Step 2: Signal Bar

    private var step2SignalBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 2: 信号K线").font(.headline)

            Toggle("信号K线为强趋势K线 (Strong Trend Bar)？", isOn: $formData.isStrongTrendBar)
                .font(.subheadline)
            Text("实体巨大，影线极短").font(.caption2).foregroundStyle(.secondary)

            Toggle("收盘价接近极值 (光头/光脚)？", isOn: $formData.isCloseNearExtreme)
                .font(.subheadline)
            Text("说明一方完全掌控").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 3: Entry

    private var step3Entry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 3: 入场信号").font(.headline)

            ForEach(EntryAttempt.allCases) { attempt in
                Button {
                    formData.entryAttempt = attempt
                } label: {
                    HStack {
                        Image(systemName: formData.entryAttempt == attempt ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(formData.entryAttempt == attempt ? .indigo : .secondary)
                        VStack(alignment: .leading) {
                            Text(attempt.label).foregroundStyle(.primary)
                            if attempt == .h1l1 {
                                Text("首次尝试，80%是陷阱").font(.caption2).foregroundStyle(.orange)
                            } else {
                                Text("二次入场，成功率更高").font(.caption2).foregroundStyle(.green)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(formData.entryAttempt == attempt ? Color.indigo.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Toggle("突破后有强跟随K线 (Follow-Through)？", isOn: $formData.hasFollowThrough)
                .font(.subheadline)
        }
    }

    // MARK: - Step 4: Risk

    private var step4Risk: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 4: 风控确认").font(.headline)

            Toggle("我承诺使用 Stop Order 入场，且亏损绝不加仓摊平", isOn: $formData.acceptsRiskRules)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                Text("入场价").font(.caption).foregroundStyle(.secondary)
                TextField("入场价格", value: $formData.entryPrice, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                Text("测量高度").font(.caption).foregroundStyle(.secondary)
                TextField("波段测量高度", value: $formData.measureHeight, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                    evaluation = nil
                } label: {
                    Label("上一步", systemImage: "chevron.left")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            Spacer()
            if step < totalSteps - 1 {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    Label("下一步", systemImage: "chevron.right")
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.indigo, in: Capsule())
                        .foregroundStyle(.white)
                }
            } else {
                Button {
                    evaluation = TradeEvaluator.evaluate(formData)
                } label: {
                    Text("提交评估")
                        .font(.subheadline).fontWeight(.bold)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Result

    private func resultView(_ eval: TradeEvaluation) -> some View {
        let isApproved = eval.verdict == .approved
        let accentColor: Color = isApproved ? .green : .red
        return VStack(alignment: .leading, spacing: 12) {
            resultHeader(isApproved: isApproved, accentColor: accentColor)
            resultReasons(eval: eval, isApproved: isApproved, accentColor: accentColor)
            resultWarnings(eval: eval)
            if isApproved {
                resultPrices(eval: eval)
            }
        }
        .padding()
        .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func resultHeader(isApproved: Bool, accentColor: Color) -> some View {
        HStack {
            Image(systemName: isApproved ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title2)
                .foregroundStyle(accentColor)
            Text(isApproved ? "交易通过" : "交易否决")
                .font(.headline).fontWeight(.bold)
                .foregroundStyle(accentColor)
        }
    }

    @ViewBuilder
    private func resultReasons(eval: TradeEvaluation, isApproved: Bool, accentColor: Color) -> some View {
        if !eval.reasons.isEmpty {
            ForEach(eval.reasons, id: \.self) { reason in
                Label(reason, systemImage: isApproved ? "checkmark" : "xmark")
                    .font(.caption)
                    .foregroundStyle(isApproved ? .primary : accentColor)
            }
        }
    }

    @ViewBuilder
    private func resultWarnings(eval: TradeEvaluation) -> some View {
        if !eval.warnings.isEmpty {
            Divider()
            ForEach(eval.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func resultPrices(eval: TradeEvaluation) -> some View {
        HStack(spacing: 16) {
            if let stop = eval.stopOrderPrice {
                VStack {
                    Text("入场价").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.2f", stop)).font(.subheadline).fontWeight(.bold)
                }
            }
            if let target = eval.targetPrice {
                VStack {
                    Text("目标位").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.2f", target))
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.green)
                }
            }
        }
    }
}

import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var watchlistVM: WatchlistViewModel
    @Binding var showSettings: Bool

    @State private var showSearch = false
    @State private var showTradeForm = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    stockSelectorSection
                    controlsRow
                    scanProgressSection
                    scanResultsSection
                    priceBadge
                    chartSection
                    aiLoadingSection
                    aiResultSection
                    errorSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .refreshable {
                viewModel.loadKlines()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("PA Scanner").font(.headline)
                            Text("Al Brooks · AI 分析").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        marketStatusBadge
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StockSearchView { stock in
                    viewModel.loadKlines(for: stock)
                    showSearch = false
                }
            }
            .sheet(isPresented: $showTradeForm) {
                TradeFormView()
            }
            .sheet(isPresented: $showHistory) {
                AnalysisHistoryView { stock in
                    viewModel.loadKlines(for: stock)
                    showHistory = false
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 分析").font(.title2).fontWeight(.bold)
                Text(StorageService.shared.selectedModel.components(separatedBy: "/").last ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
                + Text(viewModel.totalCost > 0 ? "  累计 $\(String(format: "%.4f", viewModel.totalCost))" : "")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Stock Selector

    private var stockSelectorSection: some View {
        HStack(spacing: 10) {
            Button {
                showSearch = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.stock.name)
                            .font(.headline).foregroundStyle(.primary)
                        Text(viewModel.stock.code)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // 收藏按钮
            Button {
                watchlistVM.toggle(viewModel.stock)
            } label: {
                Image(systemName: watchlistVM.isInWatchlist(code: viewModel.stock.code) ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(watchlistVM.isInWatchlist(code: viewModel.stock.code) ? .yellow : .secondary)
            }
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 8) {
            Button { showHistory = true } label: {
                Label("历史", systemImage: "clock.arrow.circlepath")
                    .font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Button { showTradeForm = true } label: {
                Label("手动评估", systemImage: "checklist")
                    .font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // 扫描
            Button {
                viewModel.runScan()
            } label: {
                HStack(spacing: 4) {
                    if viewModel.scanning {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(viewModel.scanning ? "扫描中" : viewModel.scanCooldown > 0 ? "\(Int(viewModel.scanCooldown))s" : "扫描")
                        .font(.caption).fontWeight(.semibold)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .disabled(viewModel.scanning || viewModel.scanCooldown > 0)
            .opacity(viewModel.scanning || viewModel.scanCooldown > 0 ? 0.6 : 1)

            // AI 分析
            Button {
                viewModel.runAnalysis()
            } label: {
                HStack(spacing: 4) {
                    if viewModel.loadingAI {
                        ProgressView().scaleEffect(0.7).tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.loadingAI ? "分析中" : viewModel.aiCooldown > 0 ? "\(Int(viewModel.aiCooldown))s" : "AI")
                        .font(.caption).fontWeight(.semibold)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .foregroundStyle(.white)
            }
            .disabled(viewModel.loadingAI || viewModel.klines.isEmpty || viewModel.aiCooldown > 0)
            .opacity(viewModel.loadingAI || viewModel.klines.isEmpty || viewModel.aiCooldown > 0 ? 0.6 : 1)
        }
    }

    // MARK: - Market Status

    private var marketStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.marketStatus.live ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(viewModel.marketStatus.text)
                .font(.caption2)
                .foregroundStyle(viewModel.marketStatus.live ? .green : .secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Price Badge

    @ViewBuilder
    private var priceBadge: some View {
        if viewModel.klines.count >= 2 {
            let last = viewModel.klines.last!
            let prev = viewModel.klines[viewModel.klines.count - 2]
            let change = last.close - prev.close
            let changePct = (change / prev.close) * 100
            let isUp = change >= 0

            HStack {
                Text(String(format: "%.2f", last.close))
                    .font(.title2).fontWeight(.bold).monospacedDigit()
                    .foregroundStyle(isUp ? .red : .green)

                Text("\(isUp ? "+" : "")\(String(format: "%.2f", change)) (\(isUp ? "+" : "")\(String(format: "%.2f", changePct))%)")
                    .font(.caption).monospacedDigit()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((isUp ? Color.red : Color.green).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(isUp ? .red : .green)

                Spacer()

                if !viewModel.lastUpdate.isEmpty {
                    HStack(spacing: 4) {
                        if viewModel.marketStatus.live {
                            Text("LIVE").font(.caption2).fontWeight(.bold).foregroundStyle(.green)
                        }
                        Text(viewModel.lastUpdate).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if viewModel.loading {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在获取 \(viewModel.stock.name) 数据...")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if !viewModel.klines.isEmpty {
            VStack(spacing: 0) {
                // 周期选择
                HStack(spacing: 0) {
                    ForEach(KlineTimeframe.allCases) { tf in
                        Button {
                            viewModel.loadKlines(timeframe: tf)
                        } label: {
                            Text(tf.label)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 16).padding(.vertical, 6)
                                .background(viewModel.timeframe == tf ? Color.indigo : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(viewModel.timeframe == tf ? .white : .secondary)
                        }
                    }
                    Spacer()
                    Button {
                        viewModel.loadKlines()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                // MA 图例
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.yellow.opacity(0.8)).frame(width: 6, height: 6)
                        Text("MA5").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.cyan.opacity(0.8)).frame(width: 6, height: 6)
                        Text("MA20").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)

                CandlestickChartView(
                    klines: viewModel.klines,
                    aiResult: viewModel.aiResult
                )
                .frame(height: 350)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - AI Loading

    @ViewBuilder
    private var aiLoadingSection: some View {
        if viewModel.loadingAI {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 正在分析 \(viewModel.stock.name)...")
                        .font(.subheadline).foregroundStyle(.indigo)
                    Text("基于 Al Brooks Price Action 策略深度分析中")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - AI Result

    @ViewBuilder
    private var aiResultSection: some View {
        if let result = viewModel.aiResult {
            AIResultView(result: result)
        }
    }

    // MARK: - Scan Progress

    @ViewBuilder
    private var scanProgressSection: some View {
        if viewModel.scanning, let progress = viewModel.scanProgress {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(progress.message).font(.caption).foregroundStyle(.orange)
                    Spacer()
                    if progress.total > 0 {
                        Text("\(progress.current)/\(progress.total)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if progress.total > 0 {
                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                        .tint(.orange)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Scan Results

    @ViewBuilder
    private var scanResultsSection: some View {
        if !viewModel.scanResults.isEmpty {
            ScanResultsView(results: viewModel.scanResults, useAI: viewModel.useAIScan) { result in
                viewModel.selectFromScan(result)
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error, !viewModel.loading {
            Text(error)
                .font(.caption).foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

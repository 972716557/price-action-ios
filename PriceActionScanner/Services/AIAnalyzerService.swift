import Foundation

actor AIAnalyzerService {
    static let shared = AIAnalyzerService()

    // MARK: - 配置

    private var apiKey: String {
        StorageService.shared.openRouterAPIKey
    }

    private let apiURL = "https://openrouter.ai/api/v1/chat/completions"

    var currentModel: String {
        get { StorageService.shared.selectedModel }
    }

    // MARK: - 单股AI分析

    func analyzeWithAI(
        klines: [KlineData],
        stockName: String,
        stockCode: String
    ) async throws -> AIAnalysisResult {
        let model = StorageService.shared.selectedModel
        let prompt = buildPrompt(klines: klines, stockName: stockName, stockCode: stockCode)

        let systemContent = "你是一位专业的 Al Brooks Price Action 交易分析师。请用中文回答，严格按要求的JSON格式输出分析结果。"

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemContent],
            ["role": "user", "content": prompt],
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": messages,
        ]

        let data = try await postRequest(body: body)
        return try parseAnalysisResult(data: data)
    }

    // MARK: - AI 精选 Top 3

    func aiSelectTopStocks(
        candidates: [(name: String, code: String, score: Int, signal: String, pattern: String, reasons: [String], klineText: String, lastPrice: Double, changePct: Double)]
    ) async throws -> [(code: String, reason: String, aiScore: Int)] {
        let model = StorageService.shared.selectedModel

        let stocksText = candidates.enumerated().map { i, s in
            """
            ### \(i + 1). \(s.name)(\(s.code)) 规则评分:\(s.score) 信号:\(s.signal) 形态:\(s.pattern)
            最新价:\(s.lastPrice) 涨跌:\(s.changePct >= 0 ? "+" : "")\(String(format: "%.2f", s.changePct))%
            规则理由: \(s.reasons.joined(separator: "; "))
            近5日K线:
            \(s.klineText)
            """
        }.joined(separator: "\n\n")

        let prompt = """
        你是 Al Brooks Price Action 专家。以下是规则引擎从A股成交额前100中预筛出的 Top \(candidates.count) 只股票。

        请从中精选出最值得关注的 **3只**，按推荐优先级排序。

        \(stocksText)

        ## 评判标准
        1. K线形态是否真正符合 Al Brooks 入场标准（强趋势K线、H2/L2、Follow-Through）
        2. 是否有明确方向感（而非震荡中的假信号）
        3. 风险回报比是否合理

        ## 输出格式（严格 JSON，不要其他内容）

        ```json
        [
          { "code": "股票代码", "reason": "推荐理由（30字内）", "aiScore": 0-100 },
          { "code": "股票代码", "reason": "推荐理由", "aiScore": 0-100 },
          { "code": "股票代码", "reason": "推荐理由", "aiScore": 0-100 }
        ]
        ```
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": "你是 Al Brooks PA 选股专家。严格按 JSON 格式输出。"],
                ["role": "user", "content": prompt],
            ] as [[String: Any]],
        ]

        let data = try await postRequest(body: body)
        return try parseAISelectionResult(data: data)
    }

    // MARK: - Private

    private func buildPrompt(klines: [KlineData], stockName: String, stockCode: String) -> String {
        let recent = Array(klines.suffix(30))
        let klineText = recent.map { k in
            "\(k.date) | 开\(k.open) 收\(k.close) 高\(k.high) 低\(k.low) 量\(Int(k.volume))"
        }.joined(separator: "\n")

        let lastPrice = recent.last?.close ?? 0

        return """
        你是一位精通 Al Brooks Price Action 交易体系的专业分析师。请根据以下K线数据，对 \(stockName)(\(stockCode)) 进行严格的 Price Action 分析。

        ## K线数据（最近30个交易日，日线）
        \(klineText)

        ## 当前收盘价: \(lastPrice)

        ## 分析要求

        请严格基于 Al Brooks 的 Price Action 理论体系进行分析，包括：

        1. **市场环境判断**：当前处于强趋势(Strong Trend)、弱趋势(Weak Trend)还是震荡区间(Trading Range)？依据是什么？
        2. **K线形态分析**：最近几根K线的特征（趋势K线、Doji、反转K线、Inside Bar、Outside Bar等）
        3. **关键形态识别**：是否出现 H2/L2 二次入场、双顶/双底、楔形、通道等形态？
        4. **入场信号判断**：是否满足 Al Brooks 的高概率入场标准？
           - 信号K线是否为强趋势K线？
           - 收盘是否接近极值？
           - 是否有 Follow-Through？
           - 是 H1/L1（首次，80%陷阱）还是 H2/L2（二次入场）？
        5. **风险评估**：潜在风险和注意事项

        ## 输出格式

        请严格按以下 JSON 格式输出，不要添加其他内容：

        ```json
        {
          "signal": "long" | "short" | "wait",
          "confidence": 0-100,
          "marketPhase": "市场环境描述",
          "pattern": "识别到的主要形态",
          "reasons": ["分析理由1", "分析理由2", ...],
          "warnings": ["风险提示1", ...],
          "entryPrice": 建议入场价或null,
          "stopLoss": 止损价或null,
          "target": 目标价或null,
          "summary": "一句话总结当前判断"
        }
        ```
        """
    }

    private func postRequest(body: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299: break
            case 401: throw AIError.invalidAPIKey
            case 429: throw AIError.rateLimited
            default: throw AIError.requestFailed(httpResponse.statusCode)
            }
        }

        return data
    }

    private func parseAnalysisResult(data: Data) throws -> AIAnalysisResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseFailed
        }

        let usage = json["usage"] as? [String: Any]

        // 提取 JSON
        let jsonStr: String
        if let range = content.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
            let start = content.index(range.lowerBound, offsetBy: content[range].hasPrefix("```json\n") ? 8 : 7)
            let end = content.index(range.upperBound, offsetBy: -3)
            jsonStr = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let range = content.range(of: "\\{[\\s\\S]*\\}", options: .regularExpression) {
            jsonStr = String(content[range])
        } else {
            throw AIError.parseFailed
        }

        guard let parsed = try JSONSerialization.jsonObject(with: jsonStr.data(using: .utf8)!) as? [String: Any] else {
            throw AIError.parseFailed
        }

        let tokenUsage: AIAnalysisResult.TokenUsage? = usage.map {
            AIAnalysisResult.TokenUsage(
                prompt: $0["prompt_tokens"] as? Int ?? 0,
                completion: $0["completion_tokens"] as? Int ?? 0,
                cost: (json["total_cost"] as? Double) ?? ($0["total_cost"] as? Double)
            )
        }

        let signalStr = parsed["signal"] as? String ?? "wait"
        let signal: TradeSignalType = TradeSignalType(rawValue: signalStr) ?? .wait

        return AIAnalysisResult(
            signal: signal,
            confidence: min(100, max(0, parsed["confidence"] as? Int ?? 0)),
            marketPhase: parsed["marketPhase"] as? String ?? "未知",
            pattern: parsed["pattern"] as? String ?? "暂无",
            reasons: parsed["reasons"] as? [String] ?? [],
            warnings: parsed["warnings"] as? [String] ?? [],
            entryPrice: parsed["entryPrice"] as? Double,
            stopLoss: parsed["stopLoss"] as? Double,
            target: parsed["target"] as? Double,
            summary: parsed["summary"] as? String ?? "",
            tokenUsage: tokenUsage
        )
    }

    private func parseAISelectionResult(data: Data) throws -> [(code: String, reason: String, aiScore: Int)] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseFailed
        }

        let jsonStr: String
        if let range = content.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
            let inner = String(content[range])
            jsonStr = inner
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let range = content.range(of: "\\[[\\s\\S]*\\]", options: .regularExpression) {
            jsonStr = String(content[range])
        } else {
            throw AIError.parseFailed
        }

        guard let list = try JSONSerialization.jsonObject(with: jsonStr.data(using: .utf8)!) as? [[String: Any]] else {
            throw AIError.parseFailed
        }

        return list.compactMap { item in
            guard let code = item["code"] as? String,
                  let reason = item["reason"] as? String,
                  let aiScore = item["aiScore"] as? Int else { return nil }
            return (code: code, reason: reason, aiScore: aiScore)
        }
    }
}

// MARK: - Error

enum AIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case requestFailed(Int)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "请先在设置中填入 OpenRouter API Key"
        case .invalidAPIKey: return "API Key 无效，请检查设置"
        case .rateLimited: return "请求过于频繁，请稍后重试"
        case .requestFailed(let code): return "AI 请求失败 (\(code))"
        case .parseFailed: return "AI 返回格式异常，无法解析"
        }
    }
}

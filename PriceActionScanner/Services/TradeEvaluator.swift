import Foundation

enum TradeEvaluator {
    static func evaluate(_ data: TradeFormData) -> TradeEvaluation {
        var reasons = [String]()
        var warnings = [String]()
        var blocked = false

        if data.context == nil {
            reasons.append("未选择市场环境 (Context)")
            blocked = true
        }

        if data.context == .tradingRange && data.isBreakoutAttempt {
            warnings.append("高风险：80% 的震荡区间突破会失败。建议在区间内高抛低吸，而非追突破。")
        }

        if !data.isStrongTrendBar {
            reasons.append("信号 K 线不是实体巨大的趋势 K 线 (Strong Trend Bar)")
            blocked = true
        }

        if !data.isCloseNearExtreme {
            reasons.append("收盘价未接近极值 (非光头/光脚)，对手方有力量")
            blocked = true
        }

        if data.entryAttempt == nil {
            reasons.append("未选择入场尝试次数 (Entry Attempt)")
            blocked = true
        }

        if data.entryAttempt == .h1l1 {
            reasons.append("当前为第一次尝试反转 (H1/L1)，80% 是陷阱，请等待 H2/L2")
            blocked = true
        }

        if !data.hasFollowThrough {
            reasons.append("突破后缺乏强有力的跟随 K 线 (Follow-Through)")
            blocked = true
        }

        if !data.acceptsRiskRules {
            reasons.append("未确认风控承诺：必须使用 Stop Order 入场，且亏损绝不加仓摊平")
            blocked = true
        }

        var stopOrderPrice: Double?
        var targetPrice: Double?

        if let entry = data.entryPrice, let height = data.measureHeight, height > 0 {
            if data.direction == .long {
                stopOrderPrice = entry
                targetPrice = ((entry + height) * 100).rounded() / 100
            } else {
                stopOrderPrice = entry
                targetPrice = ((entry - height) * 100).rounded() / 100
            }
        } else if !blocked {
            warnings.append("缺少入场价或测量高度，无法计算目标位")
        }

        return TradeEvaluation(
            verdict: blocked ? .rejected : .approved,
            reasons: reasons,
            warnings: warnings,
            stopOrderPrice: blocked ? nil : stopOrderPrice,
            targetPrice: blocked ? nil : targetPrice
        )
    }
}

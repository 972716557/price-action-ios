import Foundation

enum MarketTimeService {
    /// 获取北京时间
    private static func getBeijingTime() -> Date {
        let now = Date()
        let utcOffset = TimeZone.current.secondsFromGMT()
        let beijingOffset = 8 * 3600
        return now.addingTimeInterval(TimeInterval(beijingOffset - utcOffset))
    }

    static var isTradingHours: Bool {
        let beijing = getBeijingTime()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: beijing)
        // 周六=7 周日=1
        guard weekday >= 2 && weekday <= 6 else { return false }

        let hour = calendar.component(.hour, from: beijing)
        let minute = calendar.component(.minute, from: beijing)
        let t = hour * 60 + minute

        return (t >= 570 && t <= 690) || (t >= 780 && t <= 900)
    }

    struct MarketStatus {
        let text: String
        let live: Bool
    }

    static var marketStatus: MarketStatus {
        let beijing = getBeijingTime()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: beijing)
        guard weekday >= 2 && weekday <= 6 else {
            return MarketStatus(text: "休市", live: false)
        }

        let hour = calendar.component(.hour, from: beijing)
        let minute = calendar.component(.minute, from: beijing)
        let t = hour * 60 + minute

        if t < 570 { return MarketStatus(text: "盘前", live: false) }
        if t >= 570 && t <= 690 { return MarketStatus(text: "交易中", live: true) }
        if t > 690 && t < 780 { return MarketStatus(text: "午休", live: false) }
        if t >= 780 && t <= 900 { return MarketStatus(text: "交易中", live: true) }
        return MarketStatus(text: "已收盘", live: false)
    }

    static let liveInterval: TimeInterval = 15
}

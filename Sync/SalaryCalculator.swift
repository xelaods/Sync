import Foundation

struct SalarySummary {
    var normalMinutes: Int = 0
    var holidayMinutes: Int = 0
    var nightMinutes: Int = 0

    var normalAmount: Int = 0
    var holidayAmount: Int = 0
    var nightAmount: Int = 0

    var totalMinutes: Int {
        normalMinutes + holidayMinutes + nightMinutes
    }

    var totalAmount: Int {
        normalAmount + holidayAmount + nightAmount
    }
}

enum SalaryCalculator {

    static func summary(
        for shifts: [Shift],
        settings: WageSettings,
        month: Date,
        calendar: Calendar = .current
    ) -> SalarySummary {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return SalarySummary()
        }

        var summary = SalarySummary()

        for shift in shifts where !shift.isExcluded && interval.contains(shift.start) {
            let grossMinutes = calendar.dateComponents(
                [.minute],
                from: shift.start,
                to: shift.end
            ).minute ?? 0

            let workMinutes = max(0, grossMinutes - shift.breakMinutes)

            switch shift.kind {
            case .normal:
                summary.normalMinutes += workMinutes
            case .holiday:
                summary.holidayMinutes += workMinutes
            case .night:
                summary.nightMinutes += workMinutes
            }
        }

        summary.normalAmount = amount(minutes: summary.normalMinutes, wage: settings.baseWage)
        summary.holidayAmount = amount(minutes: summary.holidayMinutes, wage: settings.holidayWage)
        summary.nightAmount = amount(minutes: summary.nightMinutes, wage: settings.nightWage)

        return summary
    }

    /// 分 × 時給を円に丸める
    /// ここでは簡易的に四捨五入扱いにする
    static func amount(minutes: Int, wage: Int) -> Int {
        guard minutes > 0, wage > 0 else { return 0 }
        return (minutes * wage + 30) / 60
    }

    static func hoursText(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if mins == 0 {
            return "\(hours)時間"
        } else {
            return "\(hours)時間\(mins)分"
        }
    }
}

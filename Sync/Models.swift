import Foundation

enum ShiftKind: String, Codable, CaseIterable, Identifiable {
    case normal = "通常"
    case holiday = "休日"
    case night = "夜勤"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .normal: return Theme.normal
        case .holiday: return Theme.holiday
        case .night: return Theme.night
        }
    }
}

struct Shift: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = "勤務"
    var start: Date = Date()
    var end: Date = Date().addingTimeInterval(8 * 3600)
    var breakMinutes: Int = 0
    var kind: ShiftKind = .normal
    var isExcluded: Bool = false
    var memo: String = ""
    var isFromCalendar: Bool = false
}

struct WageSettings: Codable {
    var baseWage: Int = 1200
    var holidayWage: Int = 1500
    var nightWage: Int = 1400
}

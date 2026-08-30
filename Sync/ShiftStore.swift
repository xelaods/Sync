import Foundation
import SwiftUI
import Combine

final class ShiftStore: ObservableObject {

    @Published var shifts: [Shift] = [] { didSet { saveShifts() } }
    @Published var settings: WageSettings = WageSettings() { didSet { saveSettings() } }
    @Published var selectedCalendarID: String? = nil { didSet { saveCalendarSelection() } }
    @Published var isSyncing = false

    let sync = CalendarSyncService()

    private var cancellables = Set<AnyCancellable>()

    private let shiftsKey = "shifts"
    private let settingsKey = "wageSettings"
    private let calendarKey = "selectedCalendar"

    init() {
        load()
        sync.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Load / Save

    private func load() {
        if let data = UserDefaults.standard.data(forKey: shiftsKey),
           let decoded = try? JSONDecoder().decode([Shift].self, from: data) {
            shifts = decoded
        }
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(WageSettings.self, from: data) {
            settings = decoded
        }
        selectedCalendarID = UserDefaults.standard.string(forKey: calendarKey)
    }

    private func saveShifts() {
        if let data = try? JSONEncoder().encode(shifts) {
            UserDefaults.standard.set(data, forKey: shiftsKey)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func saveCalendarSelection() {
        UserDefaults.standard.set(selectedCalendarID, forKey: calendarKey)
    }

    // MARK: - CRUD & Overlap Handling

    func upsert(_ shift: Shift) {
        shifts.removeAll { existing in
            existing.id != shift.id && existing.start < shift.end && shift.start < existing.end
        }

        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[index] = shift
        } else {
            shifts.append(shift)
        }
    }

    func addShifts(_ newShifts: [Shift]) {
        let nonOverlapping = shifts.filter { existing in
            !newShifts.contains { new in
                existing.start < new.end && new.start < existing.end
            }
        }
        shifts = nonOverlapping + newShifts
    }

    func delete(_ shift: Shift) {
        shifts.removeAll { $0.id == shift.id }
    }

    // MARK: - Calendar Sync

    func requestCalendarAccess() {
        sync.requestAccess()
    }

    func syncMonth(_ month: Date) {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        let result = sync.fetchShifts(calendarID: selectedCalendarID,
                                      start: interval.start,
                                      end: interval.end)
        addShifts(result.shifts)
    }

    func syncYearToDate(completion: @escaping (String) -> Void) {
        guard sync.isAuthorized else {
            completion("❌ カレンダーに未接続です。\n設定タブの「カレンダーへ接続」から許可してください。")
            return
        }

        isSyncing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let calendar = Calendar.current
            let now = Date()
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    completion("❌ 同期期間の計算に失敗しました。")
                }
                return
            }

            let result = self.sync.fetchShifts(
                calendarID: self.selectedCalendarID,
                start: startOfYear,
                end: now
            )

            DispatchQueue.main.async {
                self.addShifts(result.shifts)
                self.isSyncing = false

                var msg = ""
                msg += "権限: \(self.sync.authorizationDescription)\n"
                msg += "対象カレンダー: \(self.selectedCalendarID == nil ? "すべて (検出 \(self.sync.calendars.count)件)" : "選択中")\n"
                msg += "期間内のiPhone上イベント: \(result.rawCount)件\n"
                msg += "(うち終日イベントで除外: \(result.allDayCount)件)\n"

                if result.rawCount == 0 {
                    msg += "\niPhone上にイベントが見つかりません。\niPhoneの 設定→カレンダー→同期→「すべてのイベント」を確認してください。"
                } else {
                    msg += "\n同期が完了しました。"
                }

                completion(msg)
            }
        }
    }

    // MARK: - Sample Data

    func addSampleShifts() {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: Date())
        guard let monthStart = calendar.date(from: monthComponents) else { return }

        var samples: [Shift] = []

        if let s = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monthStart),
           let e = calendar.date(byAdding: .hour, value: 8, to: s) {
            samples.append(Shift(title: "サンプル通常", start: s, end: e, breakMinutes: 60, kind: .normal))
        }
        if let d = calendar.date(byAdding: .day, value: 1, to: monthStart),
           let s = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: d),
           let e = calendar.date(byAdding: .hour, value: 6, to: s) {
            samples.append(Shift(title: "サンプル休日", start: s, end: e, breakMinutes: 45, kind: .holiday))
        }
        if let d = calendar.date(byAdding: .day, value: 2, to: monthStart),
           let s = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: d),
           let e = calendar.date(byAdding: .hour, value: 7, to: s) {
            samples.append(Shift(title: "サンプル夜勤", start: s, end: e, breakMinutes: 60, kind: .night))
        }

        addShifts(samples)
    }
}

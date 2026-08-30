import Foundation
import SwiftUI
import Combine

final class ShiftStore: ObservableObject {

    @Published var shifts: [Shift] = [] { didSet { saveShifts() } }
    @Published var settings: WageSettings = WageSettings() { didSet { saveSettings() } }
    @Published var selectedCalendarID: String? = nil { didSet { saveCalendarSelection() } }

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
        // 自分自身以外で時間が被っているものを削除
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
        // 新しいシフト群と時間が被る既存シフトを削除
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
        let fetched = sync.fetchShifts(calendarID: selectedCalendarID,
                                       start: interval.start,
                                       end: interval.end)
        addShifts(fetched)
    }
    
    func syncYearToDate() {
        let calendar = Calendar.current
        let now = Date()
        let yearComponents = calendar.dateComponents([.year], from: now)
        guard let startOfYear = calendar.date(from: yearComponents) else { return }
        
        let fetched = sync.fetchShifts(calendarID: selectedCalendarID,
                                       start: startOfYear,
                                       end: now)
        addShifts(fetched)
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

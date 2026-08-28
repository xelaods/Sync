import Foundation
import SwiftUI

final class ShiftStore: ObservableObject {

    @Published var shifts: [Shift] = [] {import Foundation
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

    // MARK: - CRUD

    func upsert(_ shift: Shift) {
        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[index] = shift
        } else {
            shifts.append(shift)
        }
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
        shifts.removeAll { $0.isFromCalendar && interval.contains($0.start) }
        shifts.append(contentsOf: fetched)
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

        shifts.append(contentsOf: samples)
    }
}
        didSet { saveShifts() }
    }

    @Published var settings: WageSettings = WageSettings() {
        didSet { saveSettings() }
    }

    private let shiftsKey = "shifts"
    private let settingsKey = "wageSettings"

    init() {
        load()
    }

    // MARK: - Load / Save

    private func load() {
        if let shiftsData = UserDefaults.standard.data(forKey: shiftsKey),
           let decodedShifts = try? JSONDecoder().decode([Shift].self, from: shiftsData) {
            shifts = decodedShifts
        }

        if let settingsData = UserDefaults.standard.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(WageSettings.self, from: settingsData) {
            settings = decodedSettings
        }
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

    // MARK: - CRUD

    func upsert(_ shift: Shift) {
        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[index] = shift
        } else {
            shifts.append(shift)
        }
    }

    func delete(_ shift: Shift) {
        shifts.removeAll { $0.id == shift.id }
    }

    // MARK: - Sample Data

    func addSampleShifts() {
        let calendar = Calendar.current
        let now = Date()
        let monthComponents = calendar.dateComponents([.year, .month], from: now)

        guard let monthStart = calendar.date(from: monthComponents) else { return }

        var samples: [Shift] = []

        // サンプル1：通常勤務
        if let start1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monthStart),
           let end1 = calendar.date(byAdding: .hour, value: 8, to: start1) {
            samples.append(
                Shift(
                    title: "サンプル通常",
                    start: start1,
                    end: end1,
                    breakMinutes: 60,
                    kind: .normal
                )
            )
        }

        // サンプル2：休日勤務
        if let day2 = calendar.date(byAdding: .day, value: 1, to: monthStart),
           let start2 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day2),
           let end2 = calendar.date(byAdding: .hour, value: 6, to: start2) {
            samples.append(
                Shift(
                    title: "サンプル休日",
                    start: start2,
                    end: end2,
                    breakMinutes: 45,
                    kind: .holiday
                )
            )
        }

        // サンプル3：夜勤
        if let day3 = calendar.date(byAdding: .day, value: 2, to: monthStart),
           let start3 = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day3),
           let end3 = calendar.date(byAdding: .hour, value: 7, to: start3) {
            samples.append(
                Shift(
                    title: "サンプル夜勤",
                    start: start3,
                    end: end3,
                    breakMinutes: 60,
                    kind: .night
                )
            )
        }

        shifts.append(contentsOf: samples)
    }
}

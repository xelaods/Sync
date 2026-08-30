import Foundation
import EventKit

final class CalendarSyncService: ObservableObject {

    private let store = EKEventStore()

    @Published var isAuthorized = false
    @Published var calendars: [EKCalendar] = []

    func requestAccess() {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.reloadCalendars() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.reloadCalendars() }
                }
            }
        }
    }

    func reloadCalendars() {
        calendars = store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    var authorizationDescription: String {
        if #available(iOS 17.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess:    return "フルアクセス"
            case .writeOnly:     return "追加のみ"
            case .denied:        return "拒否"
            case .restricted:    return "制限"
            case .notDetermined: return "未確定"
            @unknown default:    return "不明"
            }
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized ? "許可済み" : "未許可"
        }
    }

    struct FetchResult {
        let shifts: [Shift]
        let rawCount: Int
        let allDayCount: Int
    }

    func fetchShifts(calendarID: String?, start: Date, end: Date) -> FetchResult {
        var target: [EKCalendar]? = nil
        if let calendarID, let cal = calendars.first(where: { $0.calendarIdentifier == calendarID }) {
            target = [cal]
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: target)
        let events = store.events(matching: predicate)

        let allDayCount = events.filter { $0.isAllDay }.count

        let shifts = events
            .filter { !$0.isAllDay }
            .map { event in
                Shift(
                    title: event.title ?? "勤務",
                    start: event.startDate,
                    end: event.endDate,
                    breakMinutes: 0,
                    kind: .normal,
                    isExcluded: false,
                    memo: event.notes ?? "",
                    isFromCalendar: true
                )
            }

        return FetchResult(shifts: shifts, rawCount: events.count, allDayCount: allDayCount)
    }

    // MARK: - Write (アプリ → Googleカレンダー)

    struct WriteResult {
        let added: Int
        let skipped: Int
        let calendarTitle: String?
    }

    func writeShifts(_ shifts: [Shift], calendarID: String?) -> WriteResult {
        guard let target = calendars.first(where: { $0.calendarIdentifier == calendarID })
                ?? store.defaultCalendarForNewEvents else {
            return WriteResult(added: 0, skipped: shifts.count, calendarTitle: nil)
        }

        guard let rangeStart = shifts.map({ $0.start }).min(),
              let rangeEnd = shifts.map({ $0.end }).max() else {
            return WriteResult(added: 0, skipped: 0, calendarTitle: target.title)
        }

        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: [target])
        let existing = store.events(matching: predicate)

        var added = 0
        var skipped = 0

        for shift in shifts {
            let overlaps = existing.contains { $0.startDate < shift.end && shift.start < $0.endDate }
            if overlaps {
                skipped += 1
                continue
            }

            let event = EKEvent(eventStore: store)
            event.title = shift.title
            event.startDate = shift.start
            event.endDate = shift.end
            event.notes = shift.memo.isEmpty ? "Sync" : shift.memo
            event.calendar = target

            do {
                try store.save(event, span: .thisEvent)
                added += 1
            } catch {
                skipped += 1
            }
        }

        return WriteResult(added: added, skipped: skipped, calendarTitle: target.title)
    }
}

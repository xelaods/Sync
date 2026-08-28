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

    func fetchShifts(calendarID: String?, start: Date, end: Date) -> [Shift] {
        var target: [EKCalendar]? = nil
        if let calendarID,
           let cal = calendars.first(where: { $0.calendarIdentifier == calendarID }) {
            target = [cal]
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: target)
        let events = store.events(matching: predicate)

        return events
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
    }
}

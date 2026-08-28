import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let shifts: [Shift]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            shifts: shiftsOn(date)
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        let leading = calendar.dateComponents([.day], from: firstWeek.start, to: monthInterval.start).day ?? 0
        for _ in 0..<leading { days.append(nil) }

        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }

    private func shiftsOn(_ date: Date) -> [Shift] {
        shifts.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let shifts: [Shift]

    private var dotColor: Color? {
        shifts.first?.kind.color
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Theme.textPrimary)

            Circle()
                .fill(dotColor ?? .clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isToday ? Theme.primary.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

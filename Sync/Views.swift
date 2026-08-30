import SwiftUI
import Charts

// MARK: - Root

struct ContentView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem { Label("給料", systemImage: "yensign.circle.fill") }

            ShiftsView()
                .tabItem { Label("シフト", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .tint(Theme.primary)
    }
}

// MARK: - Summary (給料)

struct SummaryView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Date()

    private var summary: SalarySummary {
        SalaryCalculator.summary(for: store.shifts, settings: store.settings, month: month)
    }

    private var monthlyData: [(month: Date, amount: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)

        var data: [(Date, Int)] = []
        for m in 1...12 {
            var comps = DateComponents()
            comps.year = year
            comps.month = m
            if let date = calendar.date(from: comps) {
                if date <= now || calendar.isDate(date, equalTo: now, toGranularity: .month) {
                    let sum = SalaryCalculator.summary(for: store.shifts, settings: store.settings, month: date)
                    data.append((date, sum.totalAmount))
                }
            }
        }
        return data
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    chartCard
                    hoursCard
                    breakdownCard
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("給料")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").foregroundColor(.white)
                }
                Spacer()
                Text(month, format: .dateTime.year().month())
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").foregroundColor(.white)
                }
            }

            VStack(spacing: 4) {
                Text("想定月給")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(summary.totalAmount)円")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                headerStat(title: "合計時間", value: SalaryCalculator.hoursText(minutes: summary.totalMinutes))
                headerStat(title: "勤務日数", value: "\(workDays)日")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.gradient))
    }

    private func headerStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundColor(.white)
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
    }

    private var workDays: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return 0 }
        let days = Set(store.shifts.filter { !$0.isExcluded && interval.contains($0.start) }
            .map { calendar.startOfDay(for: $0.start) })
        return days.count
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月別推移 (今年)").font(.subheadline.weight(.semibold)).foregroundColor(Theme.textSecondary)

            if monthlyData.isEmpty {
                Text("データがありません").foregroundColor(Theme.textSecondary).frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("月", item.month, unit: .month),
                        y: .value("給与", item.amount)
                    )
                    .foregroundStyle(Theme.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel().foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .card()
    }

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("勤務時間").font(.subheadline.weight(.semibold)).foregroundColor(Theme.textSecondary)
            hourRow("通常", minutes: summary.normalMinutes, color: Theme.normal)
            hourRow("休日", minutes: summary.holidayMinutes, color: Theme.holiday)
            hourRow("夜勤", minutes: summary.nightMinutes, color: Theme.night)
        }
        .card()
    }

    private func hourRow(_ title: String, minutes: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).foregroundColor(Theme.textPrimary)
            Spacer()
            Text(SalaryCalculator.hoursText(minutes: minutes))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("金額内訳").font(.subheadline.weight(.semibold)).foregroundColor(Theme.textSecondary)
            amountRow("通常", amount: summary.normalAmount)
            amountRow("休日", amount: summary.holidayAmount)
            amountRow("夜勤", amount: summary.nightAmount)
            Divider().background(Color.gray.opacity(0.2))
            HStack {
                Text("合計").font(.subheadline.weight(.bold))
                Spacer()
                Text("\(summary.totalAmount)円").font(.subheadline.weight(.bold)).foregroundColor(Theme.primary)
            }
        }
        .card()
    }

    private func amountRow(_ title: String, amount: Int) -> some View {
        HStack {
            Text(title).foregroundColor(Theme.textPrimary)
            Spacer()
            Text("\(amount)円").font(.subheadline.weight(.medium)).foregroundColor(Theme.textPrimary)
        }
    }

    private func shiftMonth(_ value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }
}

// MARK: - Shifts (シフト)

struct ShiftsView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var selectedDate = Date()
    @State private var editingShift: Shift?
    @State private var isAdding = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var dayShifts: [Shift] {
        store.shifts
            .filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calendarCard
                    dayListCard
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("シフト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 24) {
                        Button {
                            store.syncYearToDate { message in
                                alertMessage = message
                                showAlert = true
                            }
                        } label: {
                            if store.isSyncing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(store.isSyncing)

                        Button { isAdding = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isAdding) { ShiftEditView(shift: nil) }
            .sheet(item: $editingShift) { ShiftEditView(shift: $0) }
            .alert("同期結果", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").foregroundColor(Theme.primary)
                }
                Spacer()
                Text(selectedDate, format: .dateTime.year().month())
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").foregroundColor(Theme.primary)
                }
            }

            MonthCalendarView(selectedDate: $selectedDate, shifts: store.shifts)
        }
        .card()
    }

    private var dayListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate, format: .dateTime.month().day().weekday())
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.textSecondary)

            if dayShifts.isEmpty {
                Text("この日のシフトはありません")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(dayShifts) { shift in
                    Button { editingShift = shift } label: {
                        ShiftRowView(shift: shift)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func shiftMonth(_ value: Int) {
        selectedDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
    }
}

struct ShiftRowView: View {
    let shift: Shift

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(shift.kind.color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(shift.title).font(.subheadline.weight(.semibold)).foregroundColor(Theme.textPrimary)
                Text("\(shift.start, format: .dateTime.hour().minute()) - \(shift.end, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(shift.kind.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundColor(shift.kind.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(shift.kind.color.opacity(0.12)))
        }
    }
}

// MARK: - Shift Edit

struct ShiftEditView: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss

    @State private var shift: Shift
    private let isNew: Bool

    init(shift: Shift?) {
        if let shift {
            _shift = State(initialValue: shift)
            isNew = false
        } else {
            _shift = State(initialValue: Shift())
            isNew = true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("タイトル", text: $shift.title)
                    DatePicker("開始", selection: $shift.start)
                    DatePicker("終了", selection: $shift.end)
                }

                Section("勤務") {
                    Stepper("休憩: \(shift.breakMinutes)分", value: $shift.breakMinutes, in: 0...480, step: 15)
                    Picker("区分", selection: $shift.kind) {
                        ForEach(ShiftKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    Toggle("計算対象外", isOn: $shift.isExcluded)
                }

                if !isNew {
                    Section {
                        Button("削除", role: .destructive) {
                            store.delete(shift)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "シフト追加" : "シフト編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.upsert(shift)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var store: ShiftStore

    var body: some View {
        NavigationStack {
            Form {
                Section("時給") {
                    wageField("通常時給", value: $store.settings.baseWage)
                    wageField("休日時給", value: $store.settings.holidayWage)
                    wageField("夜勤時給", value: $store.settings.nightWage)
                }

                Section("カレンダー同期") {
                    if store.sync.isAuthorized {
                        Picker("対象カレンダー", selection: $store.selectedCalendarID) {
                            Text("すべて").tag(String?.none)
                            ForEach(store.sync.calendars, id: \.calendarIdentifier) { cal in
                                Text(cal.title).tag(String?.some(cal.calendarIdentifier))
                            }
                        }

                        Button("今月のシフトを同期") {
                            store.syncMonth(Date())
                        }
                    } else {
                        Button("カレンダーへ接続") {
                            store.requestCalendarAccess()
                        }
                    }
                }

                Section("データ") {
                    Button("サンプルデータを追加") {
                        store.addSampleShifts()
                    }
                }
            }
            .navigationTitle("設定")
        }
    }

    private func wageField(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text("円").foregroundColor(Theme.textSecondary)
        }
    }
}

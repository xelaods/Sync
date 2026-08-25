import SwiftUI

// MARK: - Root

struct ContentView: View {
    var body: some View {
        TabView {
            SummaryView()
                .tabItem {
                    Label("サマリー", systemImage: "yensign.circle")
                }

            ShiftListView()
                .tabItem {
                    Label("シフト", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Summary

struct SummaryView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Date()

    private var summary: SalarySummary {
        SalaryCalculator.summary(
            for: store.shifts,
            settings: store.settings,
            month: month
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                monthSwitcher

                List {
                    Section("月給") {
                        LabeledContent("想定月給", value: "\(summary.totalAmount)円")
                    }

                    Section("勤務時間") {
                        LabeledContent("合計", value: SalaryCalculator.hoursText(minutes: summary.totalMinutes))
                        LabeledContent("通常", value: SalaryCalculator.hoursText(minutes: summary.normalMinutes))
                        LabeledContent("休日", value: SalaryCalculator.hoursText(minutes: summary.holidayMinutes))
                        LabeledContent("夜勤", value: SalaryCalculator.hoursText(minutes: summary.nightMinutes))
                    }

                    Section("金額内訳") {
                        LabeledContent("通常", value: "\(summary.normalAmount)円")
                        LabeledContent("休日", value: "\(summary.holidayAmount)円")
                        LabeledContent("夜勤", value: "\(summary.nightAmount)円")
                    }
                }
            }
            .navigationTitle("Sync")
        }
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(month, format: .dateTime.year().month())
                .font(.headline)

            Spacer()

            Button {
                month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Shift List

struct ShiftListView: View {
    @EnvironmentObject private var store: ShiftStore

    @State private var isAdding = false
    @State private var editingShift: Shift?

    private var sortedShifts: [Shift] {
        store.shifts.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedShifts) { shift in
                    Button {
                        editingShift = shift
                    } label: {
                        ShiftRowView(shift: shift)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { sortedShifts[$0].id }
                    store.shifts.removeAll { ids.contains($0.id) }
                }
            }
            .navigationTitle("シフト")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                ShiftEditView(shift: nil)
            }
            .sheet(item: $editingShift) { shift in
                ShiftEditView(shift: shift)
            }
        }
    }
}

struct ShiftRowView: View {
    let shift: Shift

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shift.title)
                .font(.headline)

            Text("\(shift.start, format: .dateTime.month().day().hour().minute()) - \(shift.end, format: .dateTime.hour().minute())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(shift.kind.rawValue) / 休憩\(shift.breakMinutes)分")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

                Section("メモ") {
                    TextField("メモ", text: $shift.memo)
                }
            }
            .navigationTitle(isNew ? "シフト追加" : "シフト編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
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
                    TextField("通常時給", value: $store.settings.baseWage, format: .number)
                        .keyboardType(.numberPad)

                    TextField("休日時給", value: $store.settings.holidayWage, format: .number)
                        .keyboardType(.numberPad)

                    TextField("夜勤時給", value: $store.settings.nightWage, format: .number)
                        .keyboardType(.numberPad)
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
}

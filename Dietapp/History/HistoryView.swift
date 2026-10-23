import Charts
import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30

        var id: Self { self }
        var title: LocalizedStringResource {
            switch self {
            case .week: "7 days"
            case .month: "30 days"
            }
        }
    }

    @State private var range = Range.week

    var body: some View {
        NavigationStack {
            List {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                // Recomputed on each render, so "today" stays current.
                let end = Calendar.current.startOfDay(for: .now)
                let start = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1), to: end)!
                CalorieHistory(start: start, end: end)
            }
            .navigationTitle("History")
        }
    }
}

/// Daily calories from `start` through `end`, kept live by `@Query`.
private struct CalorieHistory: View {
    let start: Date
    let end: Date

    @Query private var meals: [Meal]
    @Environment(GoalsSettings.self) private var goals

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
        _meals = Query(filter: #Predicate<Meal> { $0.day >= start && $0.day <= end })
    }

    private var totals: [DayTotal] {
        DayTotal.totals(for: meals, from: start, through: end, calendar: .current)
    }

    var body: some View {
        let totals = totals
        let loggedDays = totals.filter { $0.nutrients.calories > 0 }
        let average = loggedDays.isEmpty ? 0 : loggedDays.map(\.nutrients.calories).reduce(0, +) / Double(loggedDays.count)

        Section {
            Chart {
                ForEach(totals, id: \.day) { total in
                    BarMark(
                        x: .value("Day", total.day, unit: .day),
                        y: .value("Calories", total.nutrients.calories)
                    )
                    .foregroundStyle(total.nutrients.calories > goals.goals.calories ? Color.orange : Color.accentColor)
                }
                RuleMark(y: .value("Goal", goals.goals.calories))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: totals.count > 7 ? 7 : 1)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow).day())
                }
            }
            .frame(height: 220)
            .padding(.vertical, 8)
        } header: {
            Text("Calories per day")
        }

        Section {
            LabeledContent("Daily average", value: "\(average.formatted(.number.precision(.fractionLength(0)))) kcal")
            LabeledContent("Days logged", value: "\(loggedDays.count) of \(totals.count)")
        } footer: {
            Text("The average only counts days with something logged.")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(.preview())
        .environment(GoalsSettings())
}

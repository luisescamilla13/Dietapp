import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

struct TodayView: View {
    /// `nil` follows the clock, so the screen moves to the new day after midnight.
    @State private var selectedDay: Date?
    @State private var addingTo: MealType?
    @State private var editingGoals = false
    @State private var pickingDay = false

    private let calendar = Calendar.current

    private var day: Date { selectedDay ?? calendar.startOfDay(for: .now) }
    private var isToday: Bool { calendar.isDateInToday(day) }

    private var title: Text {
        if isToday { return Text("Today") }
        if calendar.isDateInYesterday(day) { return Text("Yesterday") }
        return Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            DayLogList(day: day, addingTo: $addingTo)
                .id(day)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Goals", systemImage: "target") { editingGoals = true }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Choose day", systemImage: "calendar") { pickingDay = true }
                        Button("Add food", systemImage: "plus") {
                            addingTo = MealType.suggested(at: .now)
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    DaySwitcher(isToday: isToday) { move(byDays: $0) } goToToday: {
                        selectedDay = nil
                    }
                }
                .sheet(item: $addingTo) { meal in
                    FoodSearchView(suggestedMeal: meal, day: day)
                }
                .sheet(isPresented: $editingGoals) {
                    GoalsView()
                }
                .sheet(isPresented: $pickingDay) {
                    DayPicker(day: day) { picked in
                        select(picked)
                        pickingDay = false
                    }
                    .presentationDetents([.medium])
                }
        }
    }

    private func move(byDays days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: day) else { return }
        select(moved)
    }

    /// Future days are clamped to today, and today goes back to following the clock.
    private func select(_ date: Date) {
        let picked = calendar.startOfDay(for: date)
        selectedDay = picked >= calendar.startOfDay(for: .now) ? nil : picked
    }
}

/// Previous and next day buttons, plus a shortcut back to today.
private struct DaySwitcher: View {
    let isToday: Bool
    let move: (Int) -> Void
    let goToToday: () -> Void

    var body: some View {
        HStack {
            Button("Previous day", systemImage: "chevron.left") { move(-1) }
                .modifier(RoundIconButton())
            Spacer()
            if !isToday {
                Button("Back to today", action: goToToday)
                    .font(.subheadline)
            }
            Spacer()
            Button("Next day", systemImage: "chevron.right") { move(1) }
                .modifier(RoundIconButton())
                .disabled(isToday)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

private struct RoundIconButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
    }
}

private struct DayPicker: View {
    @State var day: Date
    let onPick: (Date) -> Void

    var body: some View {
        NavigationStack {
            DatePicker("Day", selection: $day, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Choose day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Done") { onPick(day) }
                }
        }
    }
}

/// The meals logged on one day, kept live by `@Query`.
private struct DayLogList: View {
    @Query private var meals: [Meal]
    @Binding var addingTo: MealType?
    @Environment(GoalsSettings.self) private var goals
    @Environment(\.modelContext) private var context

    init(day: Date, addingTo: Binding<MealType?>) {
        _meals = Query(filter: #Predicate<Meal> { $0.day == day })
        _addingTo = addingTo
    }

    var body: some View {
        List {
            Section {
                MacroSummaryView(totals: meals.reduce(.zero) { $0 + $1.nutrients }, goals: goals.goals)
            }
            ForEach(MealType.allCases, id: \.self) { type in
                MealSection(type: type, meal: meals.first { $0.type == type }) {
                    addingTo = type
                } onDelete: { entry in
                    try? FoodLog(context: context).delete(entry)
                }
            }
        }
    }
}

private struct MealSection: View {
    let type: MealType
    let meal: Meal?
    let onAdd: () -> Void
    let onDelete: (FoodEntry) -> Void

    private var entries: [FoodEntry] {
        (meal?.entries ?? []).sorted { $0.loggedAt < $1.loggedAt }
    }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                NavigationLink {
                    EditEntryView(entry: entry)
                } label: {
                    EntryRow(entry: entry)
                }
            }
            .onDelete { offsets in
                offsets.map { entries[$0] }.forEach(onDelete)
            }
            Button("Add food", systemImage: "plus", action: onAdd)
        } header: {
            HStack {
                Text(type.title)
                Spacer()
                if let meal, !meal.entries.isEmpty {
                    Text("\(meal.nutrients.calories, format: .number.precision(.fractionLength(0))) kcal")
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.foodName)
                Text(entry.amountDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.nutrients.calories, format: .number.precision(.fractionLength(0))) kcal")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

extension FoodEntry {
    var amountDescription: String {
        let grams = "\(grams.formatted(.number.precision(.fractionLength(0)))) g"
        return portionName.map { "\($0) · \(grams)" } ?? grams
    }
}

extension MealType: @retroactive Identifiable {
    public var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(.preview())
        .environment(GoalsSettings())
}

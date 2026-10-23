import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

struct TodayView: View {
    @State private var addingTo: MealType?
    @State private var editingGoals = false

    var body: some View {
        NavigationStack {
            // Recomputed on each render, so the list moves to the new day after midnight.
            DayLogList(day: Calendar.current.startOfDay(for: .now), addingTo: $addingTo)
                .navigationTitle("Today")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Goals", systemImage: "target") { editingGoals = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add food", systemImage: "plus") {
                            addingTo = MealType.suggested(at: .now)
                        }
                    }
                }
                .sheet(item: $addingTo) { meal in
                    FoodSearchView(suggestedMeal: meal)
                }
                .sheet(isPresented: $editingGoals) {
                    GoalsView()
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

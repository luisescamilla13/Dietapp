import FoodParsingKit
import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

/// Turns a typed meal description into foods the user confirms before logging.
struct DescribeMealView: View {
    let day: Date
    let onLogged: () -> Void

    @Environment(\.foodParser) private var foodParser
    @Environment(\.nutritionSearch) private var nutritionSearch
    @Environment(\.modelContext) private var context
    @State private var model: DescribeMealModel?
    @State private var description = ""
    @State private var meal: MealType
    @State private var errorMessage: String?
    @FocusState private var isEditing: Bool

    init(meal: MealType, day: Date, onLogged: @escaping () -> Void) {
        self.day = day
        self.onLogged = onLogged
        _meal = State(initialValue: meal)
    }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                // A placeholder, because an empty view never appears and its `.task` wouldn't run.
                ProgressView()
            }
        }
        .navigationTitle("Describe your meal")
        .navigationBarTitleDisplayMode(.inline)
        // Created once here rather than in `body`: SwiftUI drops state changes made while
        // it renders, so a model created there would be replaced on every update.
        .task {
            guard model == nil else { return }
            model = DescribeMealModel(parser: foodParser, search: nutritionSearch)
            isEditing = true
        }
    }

    private func content(_ model: DescribeMealModel) -> some View {
        Form {
            switch model.phase {
            case .idle, .failed:
                descriptionInput(model)
            case .parsing, .matching:
                progress(model)
            case .review:
                review(model)
            }
        }
        .toolbar {
            if model.phase == .review {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add(model.includedItems) }
                        .disabled(model.includedItems.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func descriptionInput(_ model: DescribeMealModel) -> some View {
        Section {
            TextField("Two scrambled eggs and a coffee with milk", text: $description, axis: .vertical)
                .lineLimit(3...6)
                .focused($isEditing)
        } footer: {
            Text("Write it like you'd say it, in English or Spanish. You'll review everything before it's added.")
        }
        if case .failed(let message) = model.phase {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        Section {
            Button("Find foods", systemImage: "sparkles") {
                isEditing = false
                Task { await model.analyze(description) }
            }
            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private func progress(_ model: DescribeMealModel) -> some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text(model.phase == .parsing ? "Reading your meal…" : "Finding nutrition info…")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text(description)
        }
        if !model.parsedItems.isEmpty {
            Section("Found so far") {
                ForEach(Array(model.parsedItems.enumerated()), id: \.offset) { _, item in
                    LabeledContent(item.name, value: item.searchTerm)
                }
            }
        }
    }

    @ViewBuilder
    private func review(_ model: DescribeMealModel) -> some View {
        @Bindable var model = model
        Picker("Meal", selection: $meal) {
            ForEach(MealType.allCases) { Text($0.title).tag($0) }
        }
        ForEach($model.reviewItems) { $item in
            ReviewItemSection(item: $item)
        }
        if let errorMessage {
            Text(errorMessage).foregroundStyle(.red)
        }
        Section {
            Button("Start over", systemImage: "arrow.counterclockwise") {
                model.startOver()
                isEditing = true
            }
        }
    }

    private func add(_ items: [ReviewItem]) {
        let log = FoodLog(context: context)
        do {
            for item in items {
                guard let food = item.selectedFood else { continue }
                try log.log(food, grams: item.grams, portionName: item.parsed.name, to: meal, at: log.loggingDate(for: day))
            }
            onLogged()
        } catch {
            errorMessage = String(localized: "Couldn't save the foods. Try again.")
        }
    }
}

/// One parsed item: the database food it matched, its amount and whether to add it.
private struct ReviewItemSection: View {
    @Binding var item: ReviewItem

    var body: some View {
        Section {
            if item.candidates.isEmpty {
                Text("No match found. Add it with a manual search.")
                    .foregroundStyle(.secondary)
            } else {
                Toggle("Add this food", isOn: $item.isIncluded)
                Picker("Food", selection: $item.selectedFoodID) {
                    ForEach(item.candidates) { food in
                        Text(food.name).tag(Optional(food.id))
                    }
                }
                .disabled(!item.isIncluded)
                LabeledContent("Grams") {
                    TextField("Grams", value: $item.grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                .disabled(!item.isIncluded)
                if let food = item.selectedFood {
                    LabeledContent("Calories", value: "\(food.nutrients(forGrams: item.grams).calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                }
            }
        } header: {
            Text(item.parsed.name)
        }
        .onChange(of: item.selectedFoodID) {
            if let food = item.selectedFood {
                item.grams = MealMatcher.defaultGrams(for: item.parsed, food: food)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DescribeMealView(meal: .lunch, day: .now) {}
    }
    .modelContainer(.preview(withSampleData: false))
}

import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

/// Picks an amount of `food` and logs it.
struct AddFoodView: View {
    let food: Food
    let day: Date
    let onLogged: () -> Void

    @Environment(\.modelContext) private var context
    @State private var meal: MealType
    @State private var unit: Unit
    @State private var quantity: Double
    @State private var errorMessage: String?

    /// Either grams or one of the food's household portions.
    enum Unit: Hashable {
        case grams
        case portion(Portion)
    }

    init(food: Food, meal: MealType, day: Date, onLogged: @escaping () -> Void) {
        self.food = food
        self.day = day
        self.onLogged = onLogged
        _meal = State(initialValue: meal)
        if let portion = food.portions.first {
            _unit = State(initialValue: .portion(portion))
            _quantity = State(initialValue: 1)
        } else {
            _unit = State(initialValue: .grams)
            _quantity = State(initialValue: 100)
        }
    }

    private var grams: Double {
        switch unit {
        case .grams: quantity
        case .portion(let portion): quantity * portion.grams
        }
    }

    private var portionName: String? {
        guard case .portion(let portion) = unit else { return nil }
        return quantity == 1 ? portion.displayName : "\(quantity.formatted()) × \(portion.displayName)"
    }

    var body: some View {
        Form {
            Picker("Meal", selection: $meal) {
                ForEach(MealType.allCases) { Text($0.title).tag($0) }
            }
            Section("Amount") {
                Picker("Unit", selection: $unit) {
                    Text("Grams").tag(Unit.grams)
                    ForEach(food.portions, id: \.self) { portion in
                        Text("\(portion.displayName) (\(portion.grams.formatted()) g)").tag(Unit.portion(portion))
                    }
                }
                LabeledContent(unit == .grams ? "Grams" : "Quantity") {
                    TextField("Quantity", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            Section("Nutrients") {
                NutrientsList(nutrients: food.nutrients(forGrams: grams))
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle(food.displayName)
        .onChange(of: unit) { _, newUnit in
            quantity = newUnit == .grams ? 100 : 1
        }
        .toolbar {
            Button("Add", action: add)
                .disabled(grams <= 0)
        }
    }

    private func add() {
        do {
            let log = FoodLog(context: context)
            try log.log(food, named: food.displayName, grams: grams, portionName: portionName, to: meal, at: log.loggingDate(for: day))
            onLogged()
        } catch {
            errorMessage = String(localized: "Couldn't save the food. Try again.")
        }
    }
}

struct NutrientsList: View {
    let nutrients: Nutrients

    var body: some View {
        LabeledContent("Calories", value: "\(nutrients.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
        LabeledContent("Protein", value: grams(nutrients.protein))
        LabeledContent("Carbohydrates", value: grams(nutrients.carbohydrates))
        LabeledContent("Fat", value: grams(nutrients.fat))
        LabeledContent("Fiber", value: grams(nutrients.fiber))
    }

    private func grams(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}

#Preview {
    NavigationStack {
        AddFoodView(food: Food.samples[0], meal: .snack, day: .now) {}
    }
    .modelContainer(.preview(withSampleData: false))
}

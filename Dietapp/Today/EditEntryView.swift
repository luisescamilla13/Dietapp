import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

/// Changes the grams of a logged food.
struct EditEntryView: View {
    let entry: FoodEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double

    init(entry: FoodEntry) {
        self.entry = entry
        _grams = State(initialValue: entry.grams)
    }

    var body: some View {
        Form {
            Section("Amount") {
                LabeledContent("Grams") {
                    TextField("Grams", value: $grams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            Section("Nutrients") {
                NutrientsList(nutrients: entry.nutrientsPer100g.scaled(by: grams / 100))
            }
        }
        .navigationTitle(entry.foodName)
        .toolbar {
            Button("Save") {
                entry.grams = grams
                // The grams no longer match the chosen portion, so show them on their own.
                entry.portionName = nil
                try? context.save()
                dismiss()
            }
            .disabled(grams <= 0 || grams == entry.grams)
        }
    }
}

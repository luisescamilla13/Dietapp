import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

/// Changes the grams of a logged food, or deletes it.
struct EditEntryView: View {
    let entry: FoodEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double
    @State private var deleteOnDisappear = false

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
            Section {
                Button("Delete food", role: .destructive) {
                    deleteOnDisappear = true
                    dismiss()
                }
            }
        }
        .navigationTitle(entry.foodName)
        // Deleting while this screen still reads the entry would touch a deleted model,
        // so the delete waits until the screen is gone.
        .onDisappear {
            if deleteOnDisappear {
                try? FoodLog(context: context).delete(entry)
            }
        }
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

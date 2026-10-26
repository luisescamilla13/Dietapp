import FoodParsingKit
import FoodVisionKit
import LoggingKit
import NutritionKit
import SwiftData
import SwiftUI

/// Searches foods and logs the chosen one. Presented as a sheet.
struct FoodSearchView: View {
    /// Preselected in the add screen, where the user can still change it.
    let suggestedMeal: MealType
    /// The day the food is logged to.
    let day: Date

    @Environment(\.nutritionSearch) private var nutritionSearch
    @Environment(\.foodParser) private var foodParser
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var model: FoodSearchModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add food")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods in English")
                .toolbar {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                .navigationDestination(for: Food.self) { food in
                    AddFoodView(food: food, meal: suggestedMeal, day: day) { dismiss() }
                }
                .task(id: query) {
                    await searchModel.search(for: query)
                }
        }
    }

    private var searchModel: FoodSearchModel {
        if let model { return model }
        let model = FoodSearchModel(search: nutritionSearch)
        self.model = model
        return model
    }

    @ViewBuilder
    private var content: some View {
        switch model?.state ?? .idle {
        case .idle:
            List {
                Section {
                    NavigationLink {
                        DescribeMealView(meal: suggestedMeal, day: day) { dismiss() }
                    } label: {
                        Label("Describe your meal", systemImage: "sparkles")
                    }
                    .disabled(foodParser.availability != .available)
                } footer: {
                    Text(DescribeMealModel.message(for: foodParser.availability)
                        ?? String(localized: "Type a whole meal, like \"two tacos and a soda\", and review the foods before adding them."))
                }
                PhotoSuggestionsSection { suggestion in
                    query = suggestion.searchTerm
                }
                Section {
                    Text("Or search for one food above, in English: \"apple\" or \"scrambled eggs\".")
                        .foregroundStyle(.secondary)
                }
            }
        case .loading:
            ProgressView()
        case .noResults:
            ContentUnavailableView.search(text: query)
        case .failed(let message):
            ContentUnavailableView("Couldn't search", systemImage: "exclamationmark.triangle", description: Text(message))
        case .results(let foods):
            List(foods) { food in
                NavigationLink(value: food) {
                    VStack(alignment: .leading) {
                        Text(food.name)
                        Text("\(food.nutrientsPer100g.calories, format: .number.precision(.fractionLength(0))) kcal per 100 g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    FoodSearchView(suggestedMeal: .breakfast, day: .now)
        .modelContainer(.preview(withSampleData: false))
}

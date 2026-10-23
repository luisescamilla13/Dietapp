import LoggingKit
import SwiftUI

struct GoalsView: View {
    @Environment(GoalsSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NutritionGoals.default

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goals") {
                    GoalField(title: "Calories", unit: "kcal", value: $draft.calories)
                    GoalField(title: "Protein", unit: "g", value: $draft.protein)
                    GoalField(title: "Carbohydrates", unit: "g", value: $draft.carbohydrates)
                    GoalField(title: "Fat", unit: "g", value: $draft.fat)
                }
                Section {
                    Button("Reset to defaults") { draft = .default }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.goals = draft
                        dismiss()
                    }
                }
            }
            .onAppear { draft = settings.goals }
        }
    }
}

private struct GoalField: View {
    let title: LocalizedStringResource
    let unit: String
    @Binding var value: Double

    var body: some View {
        LabeledContent {
            HStack {
                TextField(String(localized: title), value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text(unit).foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
        }
    }
}

#Preview {
    GoalsView()
        .environment(GoalsSettings())
}

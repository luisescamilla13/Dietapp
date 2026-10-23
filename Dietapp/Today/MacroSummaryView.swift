import LoggingKit
import NutritionKit
import SwiftUI

/// Calories eaten against the goal, plus a ring per macronutrient.
struct MacroSummaryView: View {
    let totals: Nutrients
    let goals: NutritionGoals

    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Text("\(totals.calories, format: .number.precision(.fractionLength(0))) kcal")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                Text("of \(goals.calories, format: .number.precision(.fractionLength(0))) kcal")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                MacroRing(title: "Protein", value: totals.protein, goal: goals.protein, color: .blue)
                MacroRing(title: "Carbs", value: totals.carbohydrates, goal: goals.carbohydrates, color: .orange)
                MacroRing(title: "Fat", value: totals.fat, goal: goals.fat, color: .pink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct MacroRing: View {
    let title: LocalizedStringResource
    let value: Double
    let goal: Double
    let color: Color

    private var progress: Double { goal > 0 ? min(value / goal, 1) : 0 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.default, value: progress)
                Text("\(value, format: .number.precision(.fractionLength(0)))g")
                    .font(.callout.bold())
                    .monospacedDigit()
            }
            .frame(width: 72, height: 72)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value, format: .number.precision(.fractionLength(0))) of \(goal, format: .number.precision(.fractionLength(0))) grams"))
    }
}

#Preview {
    List {
        MacroSummaryView(
            totals: Nutrients(calories: 1240, protein: 80, carbohydrates: 120, fat: 40, fiber: 12),
            goals: .default
        )
    }
}

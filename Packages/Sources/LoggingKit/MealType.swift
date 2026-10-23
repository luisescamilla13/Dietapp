/// The meal a logged food belongs to, in the order they appear during the day.
public enum MealType: String, Sendable, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
}

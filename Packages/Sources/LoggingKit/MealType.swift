import Foundation

/// The meal a logged food belongs to, in the order they appear during the day.
public enum MealType: String, Sendable, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    /// The meal people usually eat at `date`'s hour, used to preselect one when logging.
    /// Lunch runs late to fit a Mexican "comida"; the gaps between meals are snacks.
    public static func suggested(at date: Date, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 12..<17: .lunch
        case 18..<23: .dinner
        default: .snack
        }
    }
}

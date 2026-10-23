import LoggingKit
import Observation

/// Observable wrapper so views update when the goals change.
@Observable
final class GoalsSettings {
    var goals: NutritionGoals {
        didSet { store.goals = goals }
    }

    @ObservationIgnored private let store: GoalsStore

    init(store: GoalsStore = GoalsStore()) {
        self.store = store
        goals = store.goals
    }
}

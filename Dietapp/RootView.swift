import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "fork.knife") {
                TodayView()
            }
            Tab("History", systemImage: "chart.bar") {
                HistoryView()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(.preview())
        .environment(GoalsSettings())
}

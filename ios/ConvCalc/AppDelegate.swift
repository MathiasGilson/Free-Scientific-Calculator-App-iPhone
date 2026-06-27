import SwiftUI

@main
struct ConvCalcApp: App {
    @StateObject private var historyStore = CalculationHistoryStore()
    @StateObject private var appState = ConvCalcAppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(historyStore)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

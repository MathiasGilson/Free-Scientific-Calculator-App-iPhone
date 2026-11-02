import SwiftUI

@main
struct ConvCalcApp: App {
    @StateObject private var historyStore = CalculationHistoryStore()
    @StateObject private var appState = ConvCalcAppState()
    @StateObject private var currencyRates = CurrencyRatesModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(historyStore)
                .environmentObject(appState)
                .environmentObject(currencyRates)
                .preferredColorScheme(.dark)
                .task {
                    await currencyRates.refresh()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await currencyRates.refresh() }
                }
        }
    }
}

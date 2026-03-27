import SwiftUI

enum AppTab: String, CaseIterable {
    case market
    case watchlist

    var label: String {
        switch self {
        case .market: return "行情"
        case .watchlist: return "自选"
        }
    }

    var icon: String {
        switch self {
        case .market: return "chart.bar.xaxis"
        case .watchlist: return "star.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var watchlistVM = WatchlistViewModel()
    @State private var tab: AppTab = .market
    @State private var showSettings = false

    var body: some View {
        TabView(selection: $tab) {
            DashboardView(
                viewModel: dashboardVM,
                watchlistVM: watchlistVM,
                showSettings: $showSettings
            )
            .tabItem {
                Label("行情", systemImage: "chart.bar.xaxis")
            }
            .tag(AppTab.market)

            WatchlistView(viewModel: watchlistVM) { stock in
                dashboardVM.loadKlines(for: stock)
                tab = .market
            }
            .tabItem {
                Label("自选", systemImage: "star.fill")
            }
            .tag(AppTab.watchlist)
        }
        .tint(.indigo)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

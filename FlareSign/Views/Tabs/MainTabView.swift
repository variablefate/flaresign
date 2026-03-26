import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            IdentitiesTab()
                .tabItem {
                    Label("Identities", systemImage: "key.fill")
                }
                .tag(0)

            AppsTab()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }
                .tag(1)

            ActivityTab()
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(2)

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.rfPrimary)
        .task {
            await appState.startNIP46Service()
        }
        .sheet(isPresented: Binding(
            get: { appState.requestQueue.currentRequest != nil },
            set: { _ in }  // prevent swipe-dismiss — must use Approve/Deny buttons
        )) {
            ApproveRequestSheet()
                .interactiveDismissDisabled(true)
        }
    }
}

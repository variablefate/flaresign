import SwiftUI
import SwiftData

@main
struct FlareSignApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(for: [
                    Identity.self,
                    ConnectedApp.self,
                    Permission.self,
                    ActivityLogEntry.self,
                ])
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                ZStack {
                    Color.rfSurface.ignoresSafeArea()
                    ProgressView().tint(.rfPrimary)
                }
            case .onboarding:
                WelcomeView()
            case .ready:
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appState.setup(modelContext: modelContext)
        }
    }
}

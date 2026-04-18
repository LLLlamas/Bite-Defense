import SwiftUI

@main
struct BiteDefenseApp: App {
    /// One coordinator for the app's lifetime — carries the SaveManager,
    /// game state, and auto-save loop. Parented here (not in `ContentView`)
    /// so scene-phase hooks can reach it.
    @State private var coordinator = GameCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // Foregrounded → backgrounded. Save immediately so an offline
                // session starts with a correct `savedAt` timestamp.
                coordinator.saveNow()
            case .active:
                break
            @unknown default:
                break
            }
        }
    }
}

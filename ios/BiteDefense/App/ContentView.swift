import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var coordinator = GameCoordinator()
    @State private var scene: GameScene = {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HUDView(coordinator: coordinator)
                Spacer()

                // Mid-screen overlays — only one at a time.
                if coordinator.placement != nil {
                    PlacementConfirmTray(coordinator: coordinator)
                        .padding(.bottom, 10)
                } else if coordinator.selectedBuildingId != nil {
                    BuildingInfoPanel(coordinator: coordinator)
                        .padding(.bottom, 10)
                }

                StorePanel(coordinator: coordinator)
            }
        }
        .onAppear { scene.coordinator = coordinator }
    }
}

#Preview {
    ContentView()
}

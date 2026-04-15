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

                // Mid-screen overlays — at most one at a time.
                if coordinator.placement != nil {
                    PlacementConfirmTray(coordinator: coordinator)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if coordinator.trainingPanelCampId != nil {
                    TrainingPanel(coordinator: coordinator)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if coordinator.selectedBuildingId != nil {
                    BuildingInfoPanel(coordinator: coordinator)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                StorePanel(coordinator: coordinator)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.placement?.type)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.trainingPanelCampId)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.selectedBuildingId)
        }
        .onAppear { scene.coordinator = coordinator }
    }
}

#Preview {
    ContentView()
}

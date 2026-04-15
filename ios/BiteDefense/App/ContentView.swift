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

                // Phase-dependent middle overlays.
                Group {
                    switch coordinator.state.phase {
                    case .building:
                        buildingPhaseOverlays
                    case .preBattle:
                        EmptyView()
                    case .battle:
                        EmptyView()
                    case .waveComplete, .waveFailed:
                        WaveResultCard(coordinator: coordinator)
                            .padding(.bottom, 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Phase-dependent bottom strip.
                switch coordinator.state.phase {
                case .building:
                    if coordinator.placement != nil ||
                       coordinator.selectedBuildingId != nil ||
                       coordinator.trainingPanelCampId != nil {
                        StorePanel(coordinator: coordinator)
                    } else {
                        BottomPanel(coordinator: coordinator)
                        StorePanel(coordinator: coordinator)
                    }
                case .preBattle:
                    PreBattleBar(coordinator: coordinator)
                case .battle:
                    BattleBar(coordinator: coordinator)
                case .waveComplete, .waveFailed:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.state.phase)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.placement?.type)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.trainingPanelCampId)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.selectedBuildingId)
        }
        .onAppear { scene.coordinator = coordinator }
    }

    @ViewBuilder
    private var buildingPhaseOverlays: some View {
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
    }
}

#Preview {
    ContentView()
}

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
                bottomStrip
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.state.phase)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.placement?.type)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.trainingPanelCampId)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.selectedBuildingId)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.storeOpen)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.pendingTroopMove)

            // Floating corner buttons — only during BUILDING phase, and only
            // when no placement/panel is active (keeps the screen uncluttered).
            if coordinator.state.phase == .building,
               coordinator.placement == nil,
               coordinator.selectedBuildingId == nil,
               coordinator.trainingPanelCampId == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CornerActionButtons(coordinator: coordinator)
                            .padding(.trailing, 14)
                            .padding(.bottom, 92)
                    }
                }
                .allowsHitTesting(true)
            }

            // Modal intro/info card.
            if coordinator.infoCardVisible {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { coordinator.dismissInfoCard() }
                IntroCard(coordinator: coordinator)
                    .transition(.scale.combined(with: .opacity))
            }

            // Guidance overlay — shown when the player tries an action that
            // isn't allowed yet (e.g. "Start Wave" with no troops).
            if let msg = coordinator.guidanceMessage {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { coordinator.dismissGuidance() }
                GuidanceCard(message: msg) {
                    coordinator.dismissGuidance()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.infoCardVisible)
        .animation(.easeInOut(duration: 0.25), value: coordinator.guidanceMessage)
        .onAppear {
            scene.coordinator = coordinator
            coordinator.showInfoCardIfFirstTime()
        }
    }

    @ViewBuilder
    private var bottomStrip: some View {
        switch coordinator.state.phase {
        case .building:
            // When a placement / selection / training panel is up, the store is
            // in the way — hide the bottom wave bar. Store is toggleable via
            // the 🛒 button when the player wants to browse.
            if coordinator.placement != nil ||
               coordinator.selectedBuildingId != nil ||
               coordinator.trainingPanelCampId != nil {
                StorePanel(coordinator: coordinator)
            } else {
                BottomPanel(coordinator: coordinator)
                if coordinator.storeOpen {
                    StorePanel(coordinator: coordinator)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        case .preBattle:
            PreBattleBar(coordinator: coordinator)
        case .battle:
            BattleBar(coordinator: coordinator)
        case .waveComplete, .waveFailed:
            EmptyView()
        }
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

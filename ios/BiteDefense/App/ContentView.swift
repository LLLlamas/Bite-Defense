import SwiftUI
import SpriteKit

struct ContentView: View {
    /// Owned by `BiteDefenseApp` so scene-phase hooks (save on background)
    /// can reach it. Passed in via init.
    @Bindable var coordinator: GameCoordinator
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
                       value: coordinator.settingsOpen)
            .animation(.spring(response: 0.32, dampingFraction: 0.86),
                       value: coordinator.pendingTroopMove)

            // Modal intro/info card.
            if coordinator.infoCardVisible {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { coordinator.dismissInfoCard() }
                IntroCard(coordinator: coordinator)
                    .transition(.scale.combined(with: .opacity))
            }

            // Level-up celebration — pops up whenever the player crosses
            // an XP threshold. Highlights any newly unlocked content.
            if let info = coordinator.levelUpPresentation {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { coordinator.dismissLevelUp() }
                LevelUpCard(info: info) {
                    coordinator.dismissLevelUp()
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
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

            // Welcome-back card — shown once per cold launch when offline
            // catch-up applied any progress. Sits above every other overlay
            // so it's the first thing the player sees.
            if let summary = coordinator.offlineSummary {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                OfflineSummaryCard(summary: summary) {
                    coordinator.dismissOfflineSummary()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.infoCardVisible)
        .animation(.easeInOut(duration: 0.25), value: coordinator.guidanceMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.7),
                   value: coordinator.levelUpPresentation)
        .onAppear {
            scene.coordinator = coordinator
            coordinator.showInfoCardIfFirstTime()
        }
    }

    @ViewBuilder
    private var bottomStrip: some View {
        switch coordinator.state.phase {
        case .building:
            // Toolbar is always the main building-phase strip. Store +
            // Settings slide up above it when the player opens them; only one
            // of {placement tray, training panel, building info, store,
            // settings} is visible at a time because any tap mutually
            // dismisses the others via coordinator state.
            BottomPanel(coordinator: coordinator)
            if coordinator.storeOpen {
                StorePanel(coordinator: coordinator)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if coordinator.settingsOpen {
                SettingsPanel(coordinator: coordinator)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
    ContentView(coordinator: GameCoordinator())
}

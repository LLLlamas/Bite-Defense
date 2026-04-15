import SpriteKit
import Combine

/// The battlefield. Holds the camera, tile map, building visuals, and the
/// placement preview overlay. Communicates with `GameCoordinator` via
/// direct calls + `EventBus` for model→visual sync.
final class GameScene: SKScene {
    weak var coordinator: GameCoordinator?

    private var tileMap: IsoTileMap?
    private var inputHandler: InputHandler?
    private let gameCamera = SKCameraNode()
    private var debugLabel: SKLabelNode!
    private var placementPreview: SKShapeNode?
    private var buildings: [Int: Building] = [:]
    private var cancellables = Set<AnyCancellable>()

    private var lastUpdateTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = Constants.backgroundColor.skColor
        scaleMode = .resizeFill
        anchorPoint = .zero

        camera = gameCamera
        gameCamera.position = IsoMath.gridCenter()
        gameCamera.setScale(1 / Constants.defaultZoom)
        addChild(gameCamera)

        let map = IsoTileMap()
        addChild(map)
        map.build(in: view)
        tileMap = map

        debugLabel = makeDebugLabel()
        gameCamera.addChild(debugLabel)

        inputHandler = InputHandler(view: view, scene: self, camera: gameCamera)

        EventBus.shared.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in self?.handle(event: event) }
            .store(in: &cancellables)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        debugLabel?.position = CGPoint(x: -size.width / 2 + 12, y: size.height / 2 - 12)
    }

    override func update(_ currentTime: TimeInterval) {
        // Compute a frame delta. First frame has no baseline, so skip.
        let dt: Double
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        coordinator?.tick(dt: dt)

        // Cheap: rebuild placement preview each frame from coordinator state.
        refreshPlacementPreview()
    }

    private func handle(event: GameEvent) {
        switch event {
        case .tileTapped(let col, let row):
            coordinator?.tap(col: col, row: row)
            refreshDebugLabel(lastTile: (col, row))
        case .buildingPlaced(let model):
            spawnBuildingNode(for: model)
        case .buildingMoved(let id, let col, let row):
            buildings[id]?.moveTo(col: col, row: row)
        case .buildingRemoved(let id):
            if let node = buildings[id] {
                // Short "poof" as the building is removed.
                node.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 0.01, duration: 0.18),
                        SKAction.fadeOut(withDuration: 0.18)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }
            buildings.removeValue(forKey: id)
        case .buildingUpgraded(let id, let newLevel):
            buildings[id]?.setLevel(newLevel)
            buildings[id]?.playUpgradeFlash()
        case .cameraMoved:
            refreshDebugLabel()
        case .resourceGained, .resourceSpent,
             .trainingQueued, .trainingCancelled,
             .trainingBlockedNoFort, .troopTrained, .playerLeveledUp:
            break
        }
        refreshSelection()
    }

    private func spawnBuildingNode(for model: BuildingModel) {
        guard let view else { return }
        let node = Building(model: model, view: view)
        addChild(node)
        buildings[model.id] = node
        node.playPlaceAnimation()
    }

    private func refreshSelection() {
        let selectedId = coordinator?.selectedBuildingId
        for (id, node) in buildings {
            node.setSelected(id == selectedId)
        }
    }

    private func refreshPlacementPreview() {
        guard let coordinator else { return }
        guard let pm = coordinator.placement, let cand = pm.candidate else {
            placementPreview?.removeFromParent()
            placementPreview = nil
            return
        }
        let def = BuildingConfig.def(for: pm.type)
        let size = def.worldSize
        let canPlace = coordinator.buildingSystem.canPlace(type: pm.type,
                                                            col: cand.col,
                                                            row: cand.row,
                                                            ignoringId: pm.movingId)
        let isOk: Bool
        if case .success = canPlace { isOk = true } else { isOk = false }

        let preview: SKShapeNode
        if let existing = placementPreview {
            preview = existing
        } else {
            preview = SKShapeNode()
            preview.zPosition = 50
            preview.lineWidth = 2
            addChild(preview)
            placementPreview = preview
        }

        let rect = CGRect(x: 0, y: -size.height,
                          width: size.width, height: size.height)
        preview.path = CGPath(rect: rect, transform: nil)
        preview.position = IsoMath.cartToWorld(col: cand.col, row: cand.row)
        if isOk {
            preview.fillColor = SKColor(red: 0, green: 0.78, blue: 0, alpha: 0.35)
            preview.strokeColor = SKColor(red: 0, green: 0.78, blue: 0, alpha: 0.9)
        } else {
            preview.fillColor = SKColor(red: 0.86, green: 0, blue: 0, alpha: 0.35)
            preview.strokeColor = SKColor(red: 0.86, green: 0, blue: 0, alpha: 0.9)
        }
    }

    private func makeDebugLabel() -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 12
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: -size.width / 2 + 12, y: size.height / 2 - 12)
        label.zPosition = 1000
        label.text = "M6 — resources + training"
        return label
    }

    private func refreshDebugLabel(lastTile: (col: Int, row: Int)? = nil) {
        let zoom = 1 / gameCamera.xScale
        var line = String(format: "zoom %.2f", zoom)
        if let t = lastTile {
            line += "  tile(\(t.col),\(t.row))"
        }
        if let pm = coordinator?.placement {
            line += "  PLACING \(pm.type.rawValue)"
        } else if let id = coordinator?.selectedBuildingId {
            line += "  selected #\(id)"
        }
        debugLabel.text = line
    }
}

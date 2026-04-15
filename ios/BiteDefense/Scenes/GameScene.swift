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
    private var troops: [Int: TroopNode] = [:]
    private var enemies: [Int: EnemyNode] = [:]
    private var spawnIndicator: SKNode?
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
        let dt: Double
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        coordinator?.tick(dt: dt)

        refreshPlacementPreview()
        syncUnitPositions()
        syncSpawnIndicator()
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
        case .buildingDamaged(_, _, _, let amount):
            // TODO: attach damage number to building position.
            _ = amount
        case .enemySpawned(let enemy):
            spawnEnemyNode(for: enemy)
        case .enemyDamaged(_, let amount, let col, let row):
            spawnDamageNumber(amount: amount, col: col, row: row, color: .yellow)
        case .enemyDied(let id):
            if let node = enemies[id] {
                enemies.removeValue(forKey: id)
                node.playDeathAnimation()
            }
        case .troopDamaged(_, let amount, let col, let row):
            spawnDamageNumber(amount: amount, col: col, row: row, color: .red)
        case .troopDied(let id):
            troops[id]?.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
            troops.removeValue(forKey: id)
        case .troopDeployed(let id):
            if troops[id] == nil, let model = coordinator?.state.troops.first(where: { $0.id == id }) {
                spawnTroopNode(for: model)
            }
        case .troopMoved(let id, let col, let row):
            if let node = troops[id] {
                let pt = IsoMath.cartToWorld(col: col, row: row)
                node.run(SKAction.move(to: pt, duration: 0.2))
            }
        case .projectileFired(let fx, let fy, let tx, let ty, _):
            spawnProjectile(fromCol: fx, fromRow: fy, toCol: tx, toRow: ty)
        case .phaseChanged(let phase):
            if phase == .building {
                // Clear lingering battlefield nodes when we return to building.
                enemies.values.forEach { $0.removeFromParent() }
                enemies.removeAll()
                troops.values.forEach { $0.removeFromParent() }
                troops.removeAll()
                spawnIndicator?.removeFromParent()
                spawnIndicator = nil
            }
            refreshDebugLabel()
        case .cameraMoved:
            refreshDebugLabel()
        case .resourceGained, .resourceSpent,
             .trainingQueued, .trainingCancelled,
             .trainingBlockedNoFort, .troopTrained,
             .waveStarted, .waveComplete, .waveFailed,
             .playerLeveledUp:
            break
        }
        refreshSelection()
    }

    // MARK: - Unit spawning

    private func spawnBuildingNode(for model: BuildingModel) {
        guard let view else { return }
        let node = Building(model: model, view: view)
        addChild(node)
        buildings[model.id] = node
        node.playPlaceAnimation()
    }

    private func spawnTroopNode(for model: TroopModel) {
        let node = TroopNode(model: model)
        addChild(node)
        troops[model.id] = node
    }

    private func spawnEnemyNode(for model: EnemyModel) {
        let node = EnemyNode(model: model)
        addChild(node)
        enemies[model.id] = node
    }

    private func spawnDamageNumber(amount: Int, col: Double, row: Double, color: SKColor) {
        let label = SKLabelNode(text: "-\(amount)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 12
        label.fontColor = color
        label.zPosition = 100
        label.position = IsoMath.cartToWorld(col: col, row: row - 0.2)
        addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 24, duration: 0.55),
                SKAction.fadeOut(withDuration: 0.55)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func spawnProjectile(fromCol: Double, fromRow: Double,
                                 toCol: Double, toRow: Double) {
        let start = IsoMath.cartToWorld(col: fromCol, row: fromRow)
        let end   = IsoMath.cartToWorld(col: toCol,   row: toRow)
        let arrow = SKShapeNode(circleOfRadius: 2.5)
        arrow.fillColor = SKColor(white: 1, alpha: 0.9)
        arrow.strokeColor = .clear
        arrow.zPosition = 30
        arrow.position = start
        addChild(arrow)
        arrow.run(SKAction.sequence([
            SKAction.move(to: end, duration: 0.18),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Per-frame sync

    private func syncUnitPositions() {
        guard let state = coordinator?.state else { return }
        for t in state.troops {
            troops[t.id]?.update(from: t)
            troops[t.id]?.setSelected(state.selectedTroopId == t.id)
        }
        for e in state.enemies {
            enemies[e.id]?.update(from: e)
        }
    }

    private func syncSpawnIndicator() {
        guard let state = coordinator?.state else { return }
        let showing = (state.phase == .preBattle || state.phase == .battle)
        if showing, let corner = state.waveCorner {
            if spawnIndicator == nil {
                spawnIndicator = makeSpawnIndicator()
                addChild(spawnIndicator!)
            }
            spawnIndicator?.position = spawnCornerPosition(corner)
        } else {
            spawnIndicator?.removeFromParent()
            spawnIndicator = nil
        }
    }

    private func spawnCornerPosition(_ corner: Int) -> CGPoint {
        let maxCR = Double(Constants.gridCols - 1)
        let cr: (Double, Double)
        switch corner {
        case 0: cr = (0, 0)
        case 1: cr = (maxCR, 0)
        case 2: cr = (0, maxCR)
        case 3: cr = (maxCR, maxCR)
        default: cr = (0, 0)
        }
        return IsoMath.cartToWorld(col: cr.0, row: cr.1)
    }

    private func makeSpawnIndicator() -> SKNode {
        let container = SKNode()
        container.zPosition = 40
        let outer = SKShapeNode(circleOfRadius: 22)
        outer.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.9)
        outer.lineWidth = 3
        outer.fillColor = .clear
        container.addChild(outer)
        let inner = SKShapeNode(circleOfRadius: 10)
        inner.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.3)
        inner.strokeColor = .clear
        container.addChild(inner)
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        container.run(SKAction.repeatForever(pulse))
        return container
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
        label.text = "M9 — full loop"
        return label
    }

    private func refreshDebugLabel(lastTile: (col: Int, row: Int)? = nil) {
        let zoom = 1 / gameCamera.xScale
        var line = String(format: "zoom %.2f", zoom)
        if let t = lastTile {
            line += "  tile(\(t.col),\(t.row))"
        }
        if let phase = coordinator?.state.phase {
            line += "  \(phase.rawValue)"
        }
        debugLabel.text = line
    }
}

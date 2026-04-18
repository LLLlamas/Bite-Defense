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
    private var pendingMovePreview: SKShapeNode?
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

        // If a save was loaded before the scene existed, the buildingPlaced /
        // troopDeployed events fired into a nil subscriber. Replay them now
        // so the on-screen state matches the model.
        syncFromLoadedState()
    }

    /// Rebuild scene nodes from the current `GameState` — used after a cold
    /// launch where persistence restored state before the scene existed.
    /// Safe to call multiple times; existing nodes are left in place.
    private func syncFromLoadedState() {
        guard let state = coordinator?.state else { return }
        for model in state.buildings where buildings[model.id] == nil {
            spawnBuildingNode(for: model)
        }
        for model in state.troops where !model.isDead && troops[model.id] == nil {
            spawnTroopNode(for: model)
        }
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
        refreshPendingMovePreview()
        refreshSelection()
        syncUnitPositions()
        syncBuildingProgress()
        syncBuildingHighlights()
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
        case .buildingCompleted(let id, _, _):
            buildings[id]?.playUpgradeFlash()
        case .buildingDamaged(_, _, _, let amount):
            // TODO: attach damage number to building position.
            _ = amount
        case .enemySpawned(let enemy):
            spawnEnemyNode(for: enemy)
        case .enemyDamaged(let id, let amount, let col, let row):
            spawnDamageNumber(amount: amount, col: col, row: row, color: .yellow)
            enemies[id]?.playHitFlash()
        case .enemyDied(let id):
            if let node = enemies[id] {
                enemies.removeValue(forKey: id)
                node.playDeathAnimation()
            }
        case .troopDamaged(let id, let amount, let col, let row):
            spawnDamageNumber(amount: amount, col: col, row: row, color: .red)
            troops[id]?.playHitFlash()
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
                // Idle/auto-battler: troops persist across waves — only clear
                // enemies + transient overlays. The ground-truth troop list
                // is in `GameState.troops`, and nodes already on screen
                // continue to represent them.
                enemies.values.forEach { $0.removeFromParent() }
                enemies.removeAll()
                spawnIndicator?.removeFromParent()
                spawnIndicator = nil
                pendingMovePreview?.removeFromParent()
                pendingMovePreview = nil
            }
            refreshDebugLabel()
        case .cameraMoved:
            refreshDebugLabel()
        case .resourceGained(let kind, let amount):
            spawnFloatingToast(emoji: kind.emoji,
                               text: "+\(amount)",
                               color: floatColor(for: kind),
                               target: toastTarget(for: kind))
        case .resourceSpent(let kind, let amount):
            spawnFloatingToast(emoji: kind.emoji,
                               text: "-\(amount)",
                               color: .red,
                               target: toastTarget(for: kind))
        case .premiumBonesGained(let amount):
            spawnFloatingToast(emoji: "🦴", text: "+\(amount)",
                               color: SKColor(red: 0.85, green: 0.65, blue: 1.0, alpha: 1),
                               target: .bones)
        case .premiumBonesSpent(let amount):
            spawnFloatingToast(emoji: "🦴", text: "-\(amount)",
                               color: .red, target: .bones)
        case .xpGained(let amount):
            spawnFloatingToast(emoji: "⭐", text: "+\(amount) XP",
                               color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1),
                               target: .level)
        case .playerLeveledUp(let level):
            spawnFloatingToast(emoji: "🎉", text: "Level \(level)!",
                               color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1),
                               target: .level, bigger: true)
        case .trainingQueued, .trainingCancelled,
             .trainingBlockedNoFort, .troopTrained,
             .waveStarted, .waveComplete, .waveFailed:
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
        node.playDeployAnimation()
    }

    private func spawnEnemyNode(for model: EnemyModel) {
        let node = EnemyNode(model: model)
        addChild(node)
        enemies[model.id] = node
        node.playSpawnAnimation()
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

    // MARK: - Screen-space resource / XP toasts
    //
    // Each toast spawns just below its matching HUD chip, fades in while
    // drifting up to the chip, then fades out. Keeps the feedback anchored
    // to the resource the player needs to read, instead of stacking in a
    // column that would overlap the map and the HUD at once.

    private enum ToastTarget {
        case water, milk, dogCoins, bones, level
    }

    private func floatColor(for kind: ResourceKind) -> SKColor {
        switch kind {
        case .water: return SKColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1)
        case .milk:  return SKColor(red: 1.0,  green: 0.95, blue: 0.75, alpha: 1)
        case .dogCoins: return SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        }
    }

    /// Camera-local target position for each HUD chip. These are approximations
    /// matching `HUDView`'s left-to-right chip order (water, milk, coins,
    /// bones, Spacer, Level). Close enough for the toast-fly animation to
    /// read correctly at any supported device width.
    private func hudChipPoint(_ target: ToastTarget) -> CGPoint {
        let sw = size.width
        let sh = size.height
        // HUD sits under the safe-area top; chip vertical center ~= 50pt below
        // the scene's top edge in camera-local coords.
        let y = sh / 2 - 50
        switch target {
        case .water:    return CGPoint(x: -sw / 2 + 50,  y: y)
        case .milk:     return CGPoint(x: -sw / 2 + 116, y: y)
        case .dogCoins: return CGPoint(x: -sw / 2 + 174, y: y)
        case .bones:    return CGPoint(x: -sw / 2 + 226, y: y)
        case .level:    return CGPoint(x:  sw / 2 - 54,  y: y)
        }
    }

    private func spawnFloatingToast(emoji: String, text: String,
                                     color: SKColor, target: ToastTarget,
                                     bigger: Bool = false) {
        let container = SKNode()
        container.zPosition = 2000

        let font = bigger ? "AvenirNext-Heavy" : "AvenirNext-Bold"
        let fontSize: CGFloat = bigger ? 16 : 13

        let icon = SKLabelNode(text: emoji)
        icon.fontName = "AppleColorEmoji"
        icon.fontSize = fontSize
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .right
        icon.position = CGPoint(x: -3, y: 0)
        container.addChild(icon)

        let body = SKLabelNode(text: text)
        body.fontName = font
        body.fontSize = fontSize
        body.fontColor = color
        body.verticalAlignmentMode = .center
        body.horizontalAlignmentMode = .left
        body.position = CGPoint(x: 3, y: 0)
        container.addChild(body)

        let approxW = CGFloat(text.count) * fontSize * 0.58 + 28
        let bg = SKShapeNode(rectOf: CGSize(width: approxW, height: fontSize + 8),
                             cornerRadius: (fontSize + 8) / 2)
        bg.fillColor = SKColor.black.withAlphaComponent(0.72)
        bg.strokeColor = color.withAlphaComponent(0.7)
        bg.lineWidth = 1
        bg.zPosition = -1
        container.addChild(bg)

        // Pop in directly below the corresponding HUD chip, bounce once, then
        // drift a touch further down and fade out. Keeps the player's eye on
        // the chip whose value just changed.
        let chipPoint = hudChipPoint(target)
        let startPoint = CGPoint(x: chipPoint.x, y: chipPoint.y - 26)
        let endPoint   = CGPoint(x: chipPoint.x, y: chipPoint.y - 48)
        container.position = startPoint
        container.alpha = 0
        container.setScale(0.55)
        gameCamera.addChild(container)

        let popIn = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.12),
            SKAction.scale(to: 1.15, duration: 0.14)
        ])
        popIn.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.10)
        settle.timingMode = .easeInEaseOut
        let drift = SKAction.move(to: endPoint, duration: 0.50)
        drift.timingMode = .easeIn

        container.run(SKAction.sequence([
            popIn,
            settle,
            SKAction.wait(forDuration: 0.22),
            SKAction.group([
                drift,
                SKAction.fadeOut(withDuration: 0.42)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func toastTarget(for kind: ResourceKind) -> ToastTarget {
        switch kind {
        case .water: return .water
        case .milk:  return .milk
        case .dogCoins: return .dogCoins
        }
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

    private func syncBuildingHighlights() {
        guard let coordinator else { return }
        let highlighted = coordinator.highlightedBuildingIds
        for (id, node) in buildings {
            node.setGuidanceHighlight(highlighted.contains(id))
        }
    }

    private func syncBuildingProgress() {
        guard let state = coordinator?.state else { return }
        for b in state.buildings {
            buildings[b.id]?.updateBuildProgress(
                isBuilding: b.isBuilding,
                progress: b.buildProgress,
                secondsLeft: b.buildTimeRemaining
            )
        }
    }

    private func syncSpawnIndicator() {
        guard let state = coordinator?.state else { return }
        let showing = (state.phase == .preBattle || state.phase == .battle)
        if showing, let corner = state.waveCorner {
            if spawnIndicator == nil {
                let node = makeSpawnIndicator()
                spawnIndicator = node
                // Parent to the camera so it stays pinned on-screen regardless
                // of zoom or pan — user must always see which corner cats are
                // coming from.
                gameCamera.addChild(node)
            }
            spawnIndicator?.position = screenCornerPosition(corner)
        } else {
            spawnIndicator?.removeFromParent()
            spawnIndicator = nil
        }
    }

    /// Position in **camera-local** (screen) coordinates for the given corner.
    /// Since the indicator is a child of the camera, this always renders at
    /// the matching screen corner with a small inset.
    private func screenCornerPosition(_ corner: Int) -> CGPoint {
        // Asymmetric insets so the indicator sits well inside the playfield
        // strip — clear of the top HUD bar and bottom store/control toolbar.
        let sideInset: CGFloat = 50
        let topInset: CGFloat = 130
        let bottomInset: CGFloat = 170
        let w = size.width
        let h = size.height
        let halfW = w / 2 - sideInset
        let dx = halfW * gameCamera.xScale
        let topY = (h / 2 - topInset) * gameCamera.yScale
        let botY = (h / 2 - bottomInset) * gameCamera.yScale
        switch corner {
        case 0: return CGPoint(x: -dx, y:  topY) // TL
        case 1: return CGPoint(x:  dx, y:  topY) // TR
        case 2: return CGPoint(x: -dx, y: -botY) // BL
        case 3: return CGPoint(x:  dx, y: -botY) // BR
        default: return .zero
        }
    }

    private func makeSpawnIndicator() -> SKNode {
        let container = SKNode()
        container.zPosition = 1000 // above the HUD's SpriteView content
        let outer = SKShapeNode(circleOfRadius: 22)
        outer.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 0.95)
        outer.lineWidth = 3
        outer.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        container.addChild(outer)
        let cat = SKLabelNode(text: "😾")
        cat.fontSize = 18
        cat.verticalAlignmentMode = .center
        cat.horizontalAlignmentMode = .center
        container.addChild(cat)
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.55),
            SKAction.scale(to: 1.0, duration: 0.55)
        ])
        outer.run(SKAction.repeatForever(pulse))
        return container
    }

    private func refreshSelection() {
        let selectedId = coordinator?.selectedBuildingId ?? coordinator?.trainingPanelCampId
        for (id, node) in buildings {
            node.setSelected(id == selectedId)
        }
    }

    private func refreshPendingMovePreview() {
        guard let coordinator else { return }
        guard let target = coordinator.pendingTroopMove else {
            pendingMovePreview?.removeFromParent()
            pendingMovePreview = nil
            return
        }
        let node: SKShapeNode
        if let existing = pendingMovePreview {
            node = existing
        } else {
            let shape = SKShapeNode(circleOfRadius: 14)
            shape.strokeColor = SKColor(red: 0.25, green: 0.78, blue: 1.0, alpha: 0.95)
            shape.fillColor = SKColor(red: 0.25, green: 0.78, blue: 1.0, alpha: 0.25)
            shape.lineWidth = 2
            shape.zPosition = 48
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.45),
                SKAction.scale(to: 1.0, duration: 0.45)
            ]))
            shape.run(pulse)
            addChild(shape)
            pendingMovePreview = shape
            node = shape
        }
        node.position = IsoMath.cartToWorld(col: Double(target.col) + 0.5,
                                            row: Double(target.row) + 0.5)
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

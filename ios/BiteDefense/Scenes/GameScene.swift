import SpriteKit
import Combine

/// M2: isometric tile map (flat top-down for now — see `IsoMath` for naming note),
/// pannable + zoomable camera, taps emit `(col, row)` via `EventBus`.
final class GameScene: SKScene {
    private var tileMap: IsoTileMap?
    private var inputHandler: InputHandler?
    private let gameCamera = SKCameraNode()
    private var debugLabel: SKLabelNode!
    private var lastTappedTile: (col: Int, row: Int)?
    private var cancellables = Set<AnyCancellable>()

    override func didMove(to view: SKView) {
        backgroundColor = Constants.backgroundColor.skColor
        scaleMode = .resizeFill
        anchorPoint = .zero

        // Camera
        camera = gameCamera
        gameCamera.position = IsoMath.gridCenter()
        gameCamera.setScale(1 / Constants.defaultZoom)
        addChild(gameCamera)

        // Tile map
        let map = IsoTileMap()
        addChild(map)
        map.build(in: view)
        tileMap = map

        // Debug HUD label as a child of the camera so it stays glued to the screen.
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: -size.width / 2 + 12, y: size.height / 2 - 12)
        label.zPosition = 1000
        label.text = "M2 — pan / pinch / tap"
        gameCamera.addChild(label)
        debugLabel = label

        // Input
        inputHandler = InputHandler(view: view, scene: self, camera: gameCamera)

        // Subscribe to bus events to update the debug label.
        EventBus.shared.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handle(event: event)
            }
            .store(in: &cancellables)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        debugLabel?.position = CGPoint(x: -size.width / 2 + 12, y: size.height / 2 - 12)
    }

    private func handle(event: GameEvent) {
        switch event {
        case .tileTapped(let col, let row):
            lastTappedTile = (col, row)
        case .cameraMoved:
            break
        }
        refreshDebugLabel()
    }

    private func refreshDebugLabel() {
        let zoom = 1 / gameCamera.xScale
        let pos = gameCamera.position
        var line = String(format: "zoom %.2fx  cam (%.0f, %.0f)", zoom, pos.x, pos.y)
        if let t = lastTappedTile {
            line += "  tile (\(t.col), \(t.row))"
        }
        debugLabel.text = line
    }
}

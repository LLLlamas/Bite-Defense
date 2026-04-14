import SpriteKit

/// Renders the 30×30 grass grid using **four cached `SKTexture`s** (one per grass
/// shade) instanced as `SKSpriteNode`s. This replaces per-frame Canvas redraws
/// from `TileRenderer.js` — the tiles are scene-graph nodes that SpriteKit
/// batches via texture atlas automatically.
///
/// Coordinate convention (see `IsoMath.swift`):
/// - World origin (0, 0) is the top-left of the grid
/// - Tile (col, row) sits with its bottom-left corner at `(col * tileSize, -row * tileSize - tileSize)`
final class IsoTileMap: SKNode {
    private let cols: Int
    private let rows: Int
    private let tileSize: CGFloat
    private var grassTextures: [SKTexture] = []

    init(cols: Int = Constants.gridCols,
         rows: Int = Constants.gridRows,
         tileSize: CGFloat = Constants.tileSize) {
        self.cols = cols
        self.rows = rows
        self.tileSize = tileSize
        super.init()
        name = "IsoTileMap"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Must be called once after the node is added to a scene with a valid `SKView`,
    /// because `SKView.texture(from:)` is what bakes our procedural tile shapes.
    func build(in view: SKView) {
        grassTextures = Constants.grassColors.map { rgb in
            Self.makeTileTexture(view: view, size: tileSize, fill: rgb, stroke: Constants.gridLineColor)
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let seed = IsoMath.tileSeed(col: col, row: row)
                let textureIdx = min(grassTextures.count - 1, Int(seed * Double(grassTextures.count)))
                let sprite = SKSpriteNode(texture: grassTextures[textureIdx])
                sprite.anchorPoint = CGPoint(x: 0, y: 1) // top-left
                let world = IsoMath.cartToWorld(col: col, row: row, tileSize: tileSize)
                sprite.position = world
                sprite.zPosition = -10
                addChild(sprite)
            }
        }

        addChild(makeBorder())
    }

    private func makeBorder() -> SKShapeNode {
        let totalW = CGFloat(cols) * tileSize
        let totalH = CGFloat(rows) * tileSize
        let rect = CGRect(x: 0, y: -totalH, width: totalW, height: totalH)
        let border = SKShapeNode(rect: rect)
        border.strokeColor = Constants.mapBorderColor.skColor
        border.lineWidth = 3
        border.fillColor = .clear
        border.zPosition = -5
        border.name = "MapBorder"
        return border
    }

    /// Bake a single tile's pixels into an `SKTexture` once. Each instance of that
    /// tile across the 900-cell grid then references the same GPU texture.
    private static func makeTileTexture(view: SKView,
                                        size: CGFloat,
                                        fill: SKColorRGB,
                                        stroke: SKColorRGB) -> SKTexture {
        let shape = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size, height: size))
        shape.fillColor = fill.skColor
        shape.strokeColor = stroke.skColor
        shape.lineWidth = 0.5
        shape.isAntialiased = false
        let texture = view.texture(from: shape) ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }
}

extension SKColorRGB {
    var skColor: SKColor {
        SKColor(red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1.0)
    }
}

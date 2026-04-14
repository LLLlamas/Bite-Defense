import SpriteKit

/// Visual + minimal model representation of a placed building. Positioned in
/// world coordinates so it lives alongside the tile map under the camera.
///
/// M3 scope: art only. Game-state fields (HP, build progress, generation timer)
/// land in M4–M6 as their owning systems get ported.
final class Building: SKNode {
    let type: BuildingType
    let col: Int
    let row: Int
    private(set) var level: Int

    private let bodySprite: SKSpriteNode
    private let emojiLabel: SKLabelNode
    private let levelBadge: SKNode

    init(type: BuildingType, col: Int, row: Int, level: Int = 1, view: SKView) {
        self.type = type
        self.col = col
        self.row = row
        self.level = level

        let def = BuildingConfig.def(for: type)
        let size = def.worldSize

        // Body
        let texture = BuildingSprites.bodyTexture(for: type, in: view)
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.anchorPoint = CGPoint(x: 0, y: 1) // top-left
        sprite.position = .zero
        self.bodySprite = sprite

        // Emoji centered in the building footprint
        let iconSize = max(14, floor(min(size.width, size.height) * 0.55))
        let label = SKLabelNode(text: def.emoji)
        label.fontName = "AppleColorEmoji"
        label.fontSize = iconSize
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: -size.height / 2)
        self.emojiLabel = label

        // Level badge — top-right
        self.levelBadge = Self.makeLevelBadge(level: level,
                                              at: CGPoint(x: size.width - 6, y: -6))

        super.init()
        name = "Building.\(type.rawValue)"
        zPosition = 5
        position = IsoMath.cartToWorld(col: col, row: row)

        addChild(bodySprite)
        addChild(emojiLabel)
        addChild(levelBadge)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Replace the badge in-place when level changes.
    func setLevel(_ newLevel: Int) {
        guard newLevel != level else { return }
        level = newLevel
        let oldPos = levelBadge.position
        levelBadge.removeFromParent()
        let fresh = Self.makeLevelBadge(level: newLevel, at: oldPos)
        addChild(fresh)
    }

    private static func makeLevelBadge(level: Int, at position: CGPoint) -> SKNode {
        let radius: CGFloat = 8
        let container = SKNode()
        container.position = position
        container.zPosition = 10

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = SKColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1) // #2c3e50
        circle.strokeColor = SKColor(red: 1.0, green: 0.823, blue: 0.4, alpha: 1) // #ffd266
        circle.lineWidth = 1.5
        container.addChild(circle)

        let label = SKLabelNode(text: "\(level)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        container.addChild(label)
        return container
    }
}

import SpriteKit

/// Visual representation of a placed building. Owns its world-space position
/// and the level-badge UI; the authoritative model lives in
/// `GameState.buildings`. Sync via the setters below.
final class Building: SKNode {
    let buildingId: Int
    let type: BuildingType
    private(set) var col: Int
    private(set) var row: Int
    private(set) var level: Int

    private let bodySprite: SKSpriteNode
    private let emojiLabel: SKLabelNode
    private var levelBadge: SKNode

    init(model: BuildingModel, view: SKView) {
        self.buildingId = model.id
        self.type = model.type
        self.col = model.col
        self.row = model.row
        self.level = model.level

        let def = BuildingConfig.def(for: model.type)
        let size = def.worldSize

        let texture = BuildingSprites.bodyTexture(for: model.type, in: view)
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.anchorPoint = CGPoint(x: 0, y: 1)
        sprite.position = .zero
        self.bodySprite = sprite

        let iconSize = max(14, floor(min(size.width, size.height) * 0.55))
        let label = SKLabelNode(text: def.emoji)
        label.fontName = "AppleColorEmoji"
        label.fontSize = iconSize
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: -size.height / 2)
        self.emojiLabel = label

        self.levelBadge = Self.makeLevelBadge(level: model.level,
                                              at: CGPoint(x: size.width - 6, y: -6))

        super.init()
        name = "Building.\(model.type.rawValue).\(model.id)"
        zPosition = 5
        position = IsoMath.cartToWorld(col: model.col, row: model.row)

        addChild(bodySprite)
        addChild(emojiLabel)
        addChild(levelBadge)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    func moveTo(col: Int, row: Int) {
        self.col = col
        self.row = row
        position = IsoMath.cartToWorld(col: col, row: row)
    }

    func setLevel(_ newLevel: Int) {
        guard newLevel != level else { return }
        level = newLevel
        let oldPos = levelBadge.position
        levelBadge.removeFromParent()
        let fresh = Self.makeLevelBadge(level: newLevel, at: oldPos)
        addChild(fresh)
        levelBadge = fresh
    }

    func setSelected(_ selected: Bool) {
        if selected {
            let def = BuildingConfig.def(for: type)
            let size = def.worldSize
            let outline = SKShapeNode(rect: CGRect(x: -1, y: -size.height - 1,
                                                   width: size.width + 2,
                                                   height: size.height + 2),
                                      cornerRadius: 7)
            outline.strokeColor = SKColor(red: 1.0, green: 0.823, blue: 0.4, alpha: 1)
            outline.lineWidth = 3
            outline.fillColor = .clear
            outline.name = "selectionOutline"
            outline.zPosition = 20
            addChild(outline)
        } else {
            childNode(withName: "selectionOutline")?.removeFromParent()
        }
    }

    private static func makeLevelBadge(level: Int, at position: CGPoint) -> SKNode {
        let radius: CGFloat = 8
        let container = SKNode()
        container.position = position
        container.zPosition = 10

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = SKColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1)
        circle.strokeColor = SKColor(red: 1.0, green: 0.823, blue: 0.4, alpha: 1)
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

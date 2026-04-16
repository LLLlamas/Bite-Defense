import SpriteKit

final class EnemyNode: SKNode {
    let enemyId: Int
    let type: EnemyType
    private let body: SKNode
    private let hpBar: HPBar

    /// Shared texture for the temporary cat sprite. Loaded lazily so missing
    /// assets at runtime fall back to the procedural circle+emoji below.
    private static let catTexture: SKTexture? = {
        #if canImport(UIKit)
        if let image = UIImage(named: "CatEnemy") {
            return SKTexture(image: image)
        }
        #endif
        return nil
    }()

    init(model: EnemyModel) {
        self.enemyId = model.id
        self.type = model.type
        let def = EnemyConfig.def(for: model.type)

        let r: CGFloat = 10
        let isTank = model.type == .tankCat

        if let texture = EnemyNode.catTexture {
            // Temporary bitmap — aspect-preserving, scaled so the tank reads
            // slightly larger than the basic/fast variants (same as the
            // hand-drawn fallback below).
            let spriteSide = (isTank ? r * 2.6 : r * 2.1)
            let sprite = SKSpriteNode(texture: texture,
                                      size: CGSize(width: spriteSide,
                                                   height: spriteSide))
            sprite.zPosition = 0
            self.body = sprite
        } else {
            // Fallback: colored circle + emoji (original behavior).
            let group = SKNode()
            let circle = SKShapeNode(circleOfRadius: r)
            circle.fillColor = def.color.skColor
            circle.strokeColor = SKColor(white: 0, alpha: 0.8)
            circle.lineWidth = 1.5
            group.addChild(circle)

            let label = SKLabelNode(text: def.emoji)
            label.fontName = "AppleColorEmoji"
            label.fontSize = 14
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            group.addChild(label)
            self.body = group
        }

        let bar = HPBar(width: 22)
        bar.position = CGPoint(x: 0, y: r + 3)
        self.hpBar = bar

        super.init()
        name = "Enemy.\(model.id)"
        zPosition = 12
        addChild(body)
        addChild(hpBar)
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(from model: EnemyModel) {
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
    }

    func playDeathAnimation(then completion: (() -> Void)? = nil) {
        let group = SKAction.group([
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.scale(to: 0.1, duration: 0.25)
        ])
        run(SKAction.sequence([
            group,
            SKAction.run { completion?() },
            SKAction.removeFromParent()
        ]))
    }

    private func updatePosition(col: Double, row: Double) {
        position = IsoMath.cartToWorld(col: col, row: row)
    }
}

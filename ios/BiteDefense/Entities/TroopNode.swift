import SpriteKit

/// Visual representation of a troop on the battlefield. Mirrors `TroopModel`.
final class TroopNode: SKNode {
    let troopId: Int
    let type: TroopType
    private let body: SKShapeNode
    private let emoji: SKLabelNode
    private let hpBar: HPBar
    private var selectionRing: SKShapeNode?

    init(model: TroopModel) {
        self.troopId = model.id
        self.type = model.type
        let def = TroopConfig.def(for: model.type)

        let r: CGFloat = 11
        let circle = SKShapeNode(circleOfRadius: r)
        circle.fillColor = def.color.skColor
        circle.strokeColor = SKColor(white: 0, alpha: 0.8)
        circle.lineWidth = 1.5
        self.body = circle

        let label = SKLabelNode(text: def.emoji)
        label.fontName = "AppleColorEmoji"
        label.fontSize = 14
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        self.emoji = label

        let bar = HPBar(width: 22)
        bar.position = CGPoint(x: 0, y: r + 3)
        self.hpBar = bar

        super.init()
        name = "Troop.\(model.id)"
        zPosition = 10
        addChild(Self.makeAura(color: def.color.skColor))
        addChild(body)
        addChild(emoji)
        addChild(hpBar)
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(from model: TroopModel) {
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
        alpha = model.isDead ? 0 : 1
    }

    func setSelected(_ selected: Bool) {
        if selected, selectionRing == nil {
            let ring = SKShapeNode(circleOfRadius: 15)
            ring.strokeColor = .yellow
            ring.lineWidth = 2
            ring.fillColor = .clear
            ring.zPosition = -1
            addChild(ring)
            selectionRing = ring
        } else if !selected {
            selectionRing?.removeFromParent()
            selectionRing = nil
        }
    }

    /// Soft pulsing ring underneath the troop — reads as a unit "aura" like
    /// in the reference gif. Sits below everything else on the node so the
    /// body/emoji/HP bar paint on top.
    private static func makeAura(color: SKColor) -> SKShapeNode {
        // Keep the aura tight around the body so it doesn't visually bleed
        // into neighboring tiles (that made tile taps feel unresponsive).
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.strokeColor = color.withAlphaComponent(0.55)
        ring.fillColor = color.withAlphaComponent(0.18)
        ring.lineWidth = 2
        ring.zPosition = -2
        ring.setScale(0.9)
        ring.alpha = 0.85
        // Don't absorb taps — tile taps must reach the scene input handler.
        ring.isUserInteractionEnabled = false
        let pulseOut = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.9),
            SKAction.fadeAlpha(to: 0.35, duration: 0.9)
        ])
        let pulseIn = SKAction.group([
            SKAction.scale(to: 0.9, duration: 0.9),
            SKAction.fadeAlpha(to: 0.85, duration: 0.9)
        ])
        pulseOut.timingMode = .easeInEaseOut
        pulseIn.timingMode = .easeInEaseOut
        ring.run(SKAction.repeatForever(SKAction.sequence([pulseOut, pulseIn])))
        return ring
    }

    private func updatePosition(col: Double, row: Double) {
        position = IsoMath.cartToWorld(col: col, row: row)
    }
}

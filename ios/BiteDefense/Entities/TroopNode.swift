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

    private func updatePosition(col: Double, row: Double) {
        position = IsoMath.cartToWorld(col: col, row: row)
    }
}

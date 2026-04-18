import SpriteKit

/// Visual representation of a troop on the battlefield. Mirrors `TroopModel`.
/// Art is baked once per (type, level) by `UnitSprites` and shared across every
/// spawned instance; per-unit state (HP bar, selection ring) lives on this node.
final class TroopNode: SKNode {
    let troopId: Int
    let type: TroopType
    private let body: SKSpriteNode
    private let hpBar: HPBar
    private var selectionRing: SKShapeNode?
    /// Sprite side length — controls how big the plush art renders. Matches the
    /// aura radius so feet stay planted on the tile center.
    private static let spriteSide: CGFloat = 32

    init(model: TroopModel) {
        self.troopId = model.id
        self.type = model.type
        let def = TroopConfig.def(for: model.type)

        let texture = UnitSprites.dogTexture(for: model.type, level: model.level)
        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: Self.spriteSide,
                                               height: Self.spriteSide))
        // Anchor sits slightly above bottom so the plush "feet" land on the
        // tile center — matches the JSX sprite's ground shadow placement.
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        sprite.zPosition = 0
        self.body = sprite

        let bar = HPBar(width: 22)
        bar.position = CGPoint(x: 0, y: Self.spriteSide * 0.7)
        self.hpBar = bar

        super.init()
        name = "Troop.\(model.id)"
        zPosition = 10
        addChild(Self.makeAura(color: def.color.skColor))
        addChild(body)
        addChild(hpBar)
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
        startIdleAnimation()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(from model: TroopModel) {
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
        alpha = model.isDead ? 0 : 1
        // Keep the texture in sync with the troop's current level so upgrades
        // (beefier armor + helmet) actually show.
        let expected = UnitSprites.dogTexture(for: type, level: model.level)
        if body.texture !== expected { body.texture = expected }
    }

    func setSelected(_ selected: Bool) {
        if selected, selectionRing == nil {
            let ring = SKShapeNode(circleOfRadius: 16)
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

    /// Brief punch animation when the troop lands an attack.
    func playAttackAnimation() {
        body.removeAction(forKey: "attack")
        let punch = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.14)
        ])
        punch.timingMode = .easeOut
        body.run(punch, withKey: "attack")
    }

    /// Scale-from-zero pop when the troop first appears on the tile.
    func playDeployAnimation() {
        setScale(0.01)
        alpha = 0
        let pop = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.22),
            SKAction.fadeIn(withDuration: 0.18)
        ])
        pop.timingMode = .easeOut
        run(pop)
    }

    /// Quick white flash + tiny shake when this troop takes damage.
    func playHitFlash() {
        body.removeAction(forKey: "hitFlash")
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.7, duration: 0.06),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.22)
        ])
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -1.5, y: 0, duration: 0.04),
            SKAction.moveBy(x: 3, y: 0, duration: 0.06),
            SKAction.moveBy(x: -1.5, y: 0, duration: 0.04)
        ])
        body.run(SKAction.group([flash, shake]), withKey: "hitFlash")
    }

    /// Gentle head-bob loop so the plush feels alive on idle tiles. The bob
    /// starts with a tiny randomized phase so a line of troops doesn't pulse
    /// in lockstep.
    private func startIdleAnimation() {
        let phase = Double.random(in: 0...1.2)
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 1.5, duration: 0.6),
            SKAction.moveBy(x: 0, y: -1.5, duration: 0.6)
        ])
        bob.timingMode = .easeInEaseOut
        body.run(SKAction.sequence([
            SKAction.wait(forDuration: phase),
            SKAction.repeatForever(bob)
        ]), withKey: "idle")
    }

    /// Soft pulsing ring underneath the troop — reads as a unit "aura".
    /// Sits below everything else on the node so the body/HP bar paint on top.
    private static func makeAura(color: SKColor) -> SKShapeNode {
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

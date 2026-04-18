import SpriteKit

/// Visual representation of an enemy cat. Art is baked once by `UnitSprites`
/// and shared across every spawn; per-enemy state (HP bar, idle bob) lives on
/// this node. Falls back to the bundled `CatEnemy` asset — if present — for
/// legacy builds, otherwise uses the procedural plush sprite.
final class EnemyNode: SKNode {
    let enemyId: Int
    let type: EnemyType
    private let body: SKSpriteNode
    private let hpBar: HPBar

    init(model: EnemyModel) {
        self.enemyId = model.id
        self.type = model.type

        // Size: tanks read slightly larger than basic/fast cats.
        let side: CGFloat = model.type == .tankCat ? 36 : 28

        let texture: SKTexture = {
            #if canImport(UIKit)
            if let image = UIImage(named: "CatEnemy"),
               model.type == .basicCat {
                // Use the shipped bitmap only for the basic cat so upgraded
                // tank art (bigger body + collar) still renders correctly.
                return SKTexture(image: image)
            }
            #endif
            return UnitSprites.catTexture(for: model.type)
        }()

        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: side, height: side))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        sprite.zPosition = 0
        self.body = sprite

        let bar = HPBar(width: 22)
        bar.position = CGPoint(x: 0, y: side * 0.7)
        self.hpBar = bar

        super.init()
        name = "Enemy.\(model.id)"
        zPosition = 12
        addChild(body)
        addChild(hpBar)
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
        startIdleAnimation()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(from model: EnemyModel) {
        updatePosition(col: model.col, row: model.row)
        hpBar.update(hp: model.hp, maxHP: model.maxHP)
    }

    func playDeathAnimation(then completion: (() -> Void)? = nil) {
        removeAllActions()  // stop idle bob before death shrink
        body.removeAllActions()
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

    /// Small scale punch when the enemy strikes.
    func playAttackAnimation() {
        body.removeAction(forKey: "attack")
        let punch = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.14)
        ])
        punch.timingMode = .easeOut
        body.run(punch, withKey: "attack")
    }

    /// Drop-in spawn pop when an enemy appears at the map edge.
    func playSpawnAnimation() {
        setScale(0.01)
        alpha = 0
        let pop = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.28),
            SKAction.fadeIn(withDuration: 0.22)
        ])
        pop.timingMode = .easeOut
        run(pop)
    }

    /// Quick white flash + tiny shake when this enemy takes damage.
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

    /// Menacing slow sway — slightly bigger amplitude than the troops.
    private func startIdleAnimation() {
        let phase = Double.random(in: 0...1.5)
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.75),
            SKAction.moveBy(x: 0, y: -2, duration: 0.75)
        ])
        bob.timingMode = .easeInEaseOut
        body.run(SKAction.sequence([
            SKAction.wait(forDuration: phase),
            SKAction.repeatForever(bob)
        ]), withKey: "idle")
    }

    private func updatePosition(col: Double, row: Double) {
        position = IsoMath.cartToWorld(col: col, row: row)
    }
}

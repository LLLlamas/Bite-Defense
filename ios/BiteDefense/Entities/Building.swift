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
    private var buildOverlay: SKNode?
    private var buildBar: SKShapeNode?
    private var buildLabel: SKLabelNode?
    private var guidanceHighlight: SKShapeNode?

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
        // Force emoji presentation (VS16) so glyphs like ⚔️ / 🛡️ always
        // render in color even on monochrome-text fallback fonts.
        let emojiText = def.emoji.hasSuffix("\u{FE0F}")
            ? def.emoji : def.emoji + "\u{FE0F}"
        let label = SKLabelNode(text: emojiText)
        label.fontName = "AppleColorEmoji"
        label.fontSize = iconSize
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: -size.height / 2)
        // Keep the icon on top of the construction overlay so Fort / HQ
        // glyphs stay visible while the building is being built.
        label.zPosition = 16
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

    /// Quick scale-from-zero on placement.
    func playPlaceAnimation() {
        setScale(0.01)
        alpha = 0
        let pop = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.22),
            SKAction.fadeIn(withDuration: 0.18)
        ])
        pop.timingMode = .easeOut
        run(pop)
    }

    /// Brief green flash to signal an upgrade.
    func playUpgradeFlash() {
        let flash = SKShapeNode(rectOf: bodySprite.size)
        flash.position = CGPoint(x: bodySprite.size.width / 2,
                                 y: -bodySprite.size.height / 2)
        flash.fillColor = SKColor(red: 0.6, green: 1.0, blue: 0.5, alpha: 0.65)
        flash.strokeColor = .clear
        flash.zPosition = 15
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.35),
            SKAction.removeFromParent()
        ]))
    }

    /// Show / update a construction overlay on top of the building while it's
    /// under construction. Clears itself once `progress` reaches 1.0.
    func updateBuildProgress(isBuilding: Bool, progress: Double, secondsLeft: Double) {
        if !isBuilding {
            buildOverlay?.removeFromParent()
            buildOverlay = nil
            buildBar = nil
            buildLabel = nil
            bodySprite.alpha = 1.0
            return
        }
        bodySprite.alpha = 0.55
        let size = bodySprite.size
        if buildOverlay == nil {
            let overlay = SKNode()
            overlay.position = CGPoint(x: size.width / 2, y: -size.height / 2)
            overlay.zPosition = 14
            let bg = SKShapeNode(rect: CGRect(x: -size.width * 0.4, y: -4,
                                              width: size.width * 0.8, height: 8),
                                 cornerRadius: 3)
            bg.fillColor = SKColor.black.withAlphaComponent(0.65)
            bg.strokeColor = SKColor.white.withAlphaComponent(0.3)
            bg.lineWidth = 1
            overlay.addChild(bg)

            let bar = SKShapeNode(rect: CGRect(x: -size.width * 0.4, y: -4,
                                               width: 1, height: 8),
                                  cornerRadius: 2)
            bar.fillColor = SKColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 0.95)
            bar.strokeColor = .clear
            overlay.addChild(bar)
            self.buildBar = bar

            let label = SKLabelNode(text: "🔨")
            label.fontName = "AppleColorEmoji"
            label.fontSize = 14
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 16)
            overlay.addChild(label)
            self.buildLabel = label

            addChild(overlay)
            self.buildOverlay = overlay
        }
        // Resize the fill bar.
        let clamped = max(0.0, min(1.0, progress))
        let w = max(1.0, size.width * 0.8 * clamped)
        buildBar?.path = CGPath(roundedRect: CGRect(x: -size.width * 0.4, y: -4,
                                                    width: w, height: 8),
                                cornerWidth: 2, cornerHeight: 2,
                                transform: nil)
        buildLabel?.text = "🔨 \(Int(secondsLeft.rounded(.up)))s"
        buildLabel?.fontSize = 11
        buildLabel?.fontName = "AvenirNext-Bold"
        buildLabel?.fontColor = .white
    }

    /// Pulsing yellow outline used by guidance cards to point the player at a
    /// specific building ("You need dog troops" highlights training camps, etc).
    func setGuidanceHighlight(_ active: Bool) {
        if active, guidanceHighlight == nil {
            let def = BuildingConfig.def(for: type)
            let size = def.worldSize
            let ring = SKShapeNode(rect: CGRect(x: -4, y: -size.height - 4,
                                                 width: size.width + 8,
                                                 height: size.height + 8),
                                    cornerRadius: 9)
            ring.strokeColor = SKColor(red: 1.0, green: 0.92, blue: 0.3, alpha: 1)
            ring.lineWidth = 3
            ring.fillColor = SKColor(red: 1.0, green: 0.92, blue: 0.3, alpha: 0.12)
            ring.zPosition = 18
            ring.name = "guidanceHighlight"
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.45, duration: 0.55),
                    SKAction.scale(to: 1.06, duration: 0.55)
                ]),
                SKAction.group([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.55),
                    SKAction.scale(to: 1.0, duration: 0.55)
                ])
            ]))
            ring.run(pulse)
            addChild(ring)
            guidanceHighlight = ring
        } else if !active, let ring = guidanceHighlight {
            ring.removeFromParent()
            guidanceHighlight = nil
        }
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

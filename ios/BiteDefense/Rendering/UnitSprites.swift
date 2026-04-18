import UIKit
import SpriteKit

/// Bakes plush-style top-down sprites for troops (dogs) and enemies (cats).
/// Mirrors the JSX reference (`sprites.jsx` — SoldierDog, ArcherDog, BasicCat,
/// TankCat). Textures are cached per key and shared across every spawned unit.
///
/// All sprites are rendered into a fixed canvas (`baseSize`) and then displayed
/// by an `SKSpriteNode` at whatever runtime size is needed, so scaling is
/// uniform and the art stays crisp on both 2x and 3x devices.
enum UnitSprites {
    /// Native bake size. Sprite is placed centered at (0,0) within this canvas.
    private static let baseSize = CGSize(width: 48, height: 48)

    private static var troopCache: [String: SKTexture] = [:]
    private static var enemyCache: [String: SKTexture] = [:]

    static func dogTexture(for type: TroopType, level: Int) -> SKTexture {
        let key = "\(type.rawValue)-L\(min(max(level, 1), 5))"
        if let cached = troopCache[key] { return cached }
        let texture = bake { cg in
            switch type {
            case .soldier:   drawSoldierDog(cg, level: level)
            case .archer:    drawArcherDog(cg, level: level)
            case .collector: drawCollectorDog(cg, level: level)  // legacy v1 save fallback
            }
        }
        troopCache[key] = texture
        return texture
    }

    /// Kept as a standalone helper: Building rendering reuses this to draw a
    /// small "dog-in-the-house" mascot on top of the Collector House tile.
    static func collectorMascotImage(side: CGFloat = 48) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = max(UIScreen.main.scale, 2)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                                format: fmt)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: side / 2, y: side / 2)
            cg.scaleBy(x: 0.48, y: 0.48)
            drawCollectorDog(cg, level: 1)
        }
    }

    static func catTexture(for type: EnemyType) -> SKTexture {
        let key = type.rawValue
        if let cached = enemyCache[key] { return cached }
        let texture = bake { cg in
            switch type {
            case .basicCat, .fastCat: drawBasicCat(cg)
            case .tankCat:            drawTankCat(cg)
            }
        }
        enemyCache[key] = texture
        return texture
    }

    static func purgeCache() {
        troopCache.removeAll(keepingCapacity: false)
        enemyCache.removeAll(keepingCapacity: false)
    }

    // MARK: - Bake helper

    private static func bake(_ draw: (CGContext) -> Void) -> SKTexture {
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = max(UIScreen.main.scale, 2)
        let renderer = UIGraphicsImageRenderer(size: baseSize, format: fmt)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // Translate to center so drawing ops can use (0,0) as sprite center,
            // matching the SVG viewBox "-50 -50 100 100" convention from the JSX
            // (but at half-scale: our canvas is 48, JSX viewBox is 100, so we
            // scale by 0.48).
            cg.translateBy(x: baseSize.width / 2, y: baseSize.height / 2)
            cg.scaleBy(x: 0.48, y: 0.48)
            draw(cg)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    // MARK: - Palette

    private static let ink = UIColor(red: 0.16, green: 0.11, blue: 0.09, alpha: 1)

    private static let soldierFur:   [UIColor] = [hex(0xe8c892), hex(0xe8c892), hex(0xd8a86b), hex(0xc48a5a), hex(0xa6724a)]
    private static let soldierDark:  [UIColor] = [hex(0xbf9966), hex(0xbf9966), hex(0xa07a42), hex(0x885e3a), hex(0x6a4630)]
    private static let soldierArmor: [UIColor] = [hex(0x8a9cae), hex(0x7d93b6), hex(0x5a7ec8), hex(0xd5aa52), hex(0xd14a4a)]

    private static let archerFur:    [UIColor] = [hex(0xd9b88a), hex(0xd9b88a), hex(0xc8a06c), hex(0x8fa86e), hex(0x9b86b8)]
    private static let archerDark:   [UIColor] = [hex(0xa78652), hex(0xa78652), hex(0x8c6e3a), hex(0x637a46), hex(0x5a4a78)]
    private static let archerCloak:  [UIColor] = [hex(0x4faa64), hex(0x4faa64), hex(0x3e85b8), hex(0xb0395a), hex(0x3a2a5a)]

    // MARK: - Soldier Dog

    private static func drawSoldierDog(_ cg: CGContext, level: Int) {
        let idx = min(max(level - 1, 0), 4)
        let fur = soldierFur[idx]
        let furDark = soldierDark[idx]
        let armor = soldierArmor[idx]

        // Ground shadow
        fillEllipse(cg, cx: 0, cy: 30, rx: 20, ry: 5, color: UIColor(white: 0, alpha: 0.3))
        // Back legs
        fillEllipse(cg, cx: -9, cy: 20, rx: 6, ry: 8, color: furDark)
        fillEllipse(cg, cx: 11, cy: 22, rx: 6, ry: 8, color: furDark)
        // Tail
        strokeBezier(cg, color: furDark, width: 7,
                     from: CGPoint(x: -16, y: 2),
                     control: CGPoint(x: -26, y: -6),
                     to: CGPoint(x: -22, y: -16))
        strokeBezier(cg, color: fur, width: 4,
                     from: CGPoint(x: -16, y: 2),
                     control: CGPoint(x: -26, y: -6),
                     to: CGPoint(x: -22, y: -16))
        // Body
        fillEllipse(cg, cx: 0, cy: 6, rx: 19, ry: 15, color: fur)
        fillEllipse(cg, cx: 3, cy: 9, rx: 15, ry: 11,
                    color: furDark.withAlphaComponent(0.3))
        // Armor vest
        let vest = CGMutablePath()
        vest.move(to: CGPoint(x: -14, y: 0))
        vest.addQuadCurve(to: CGPoint(x: 14, y: 0), control: CGPoint(x: 0, y: -5))
        vest.addLine(to: CGPoint(x: 15, y: 14))
        vest.addQuadCurve(to: CGPoint(x: -15, y: 14), control: CGPoint(x: 0, y: 20))
        vest.closeSubpath()
        cg.addPath(vest)
        cg.setFillColor(armor.cgColor)
        cg.fillPath()
        // Shoulder pads
        fillEllipse(cg, cx: -12, cy: 2, rx: 5, ry: 4, color: armor)
        fillEllipse(cg, cx: 12, cy: 2, rx: 5, ry: 4, color: armor)
        // Front legs
        fillEllipse(cg, cx: -7, cy: 24, rx: 4.5, ry: 6, color: fur)
        fillEllipse(cg, cx: 9, cy: 25, rx: 4.5, ry: 6, color: fur)
        // Head (shifted slightly to the right)
        drawPlushDogHead(cg, offsetX: 3, offsetY: -12, r: 14, fur: fur, furDark: furDark)
        // Helmet on higher levels
        if level >= 3 {
            let helm = CGMutablePath()
            helm.move(to: CGPoint(x: -14 + 3, y: -5 - 12))
            helm.addQuadCurve(to: CGPoint(x: 14 + 3, y: -5 - 12),
                              control: CGPoint(x: 0 + 3, y: -18 - 12))
            helm.addLine(to: CGPoint(x: 14 + 3, y: -2 - 12))
            helm.addQuadCurve(to: CGPoint(x: -14 + 3, y: -2 - 12),
                              control: CGPoint(x: 0 + 3, y: -7 - 12))
            helm.closeSubpath()
            cg.addPath(helm)
            cg.setFillColor(armor.cgColor)
            cg.fillPath()
        }
    }

    // MARK: - Archer Dog

    private static func drawArcherDog(_ cg: CGContext, level: Int) {
        let idx = min(max(level - 1, 0), 4)
        let fur = archerFur[idx]
        let furDark = archerDark[idx]
        let cloak = archerCloak[idx]

        fillEllipse(cg, cx: 0, cy: 30, rx: 18, ry: 4.5, color: UIColor(white: 0, alpha: 0.3))
        fillEllipse(cg, cx: -7, cy: 20, rx: 5, ry: 7, color: furDark)
        fillEllipse(cg, cx: 9, cy: 22, rx: 5, ry: 7, color: furDark)

        // Quiver on back (tilted)
        cg.saveGState()
        cg.translateBy(x: -14, y: -2)
        cg.rotate(by: -.pi / 12)
        fillAndStrokeRect(cg, x: -4, y: -10, w: 7, h: 20, fill: hex(0x8a5a30), stroke: ink, line: 1)
        // Arrow feathers
        cg.setFillColor(hex(0xe85f3c).cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: -1, y: -13))
        cg.addLine(to: CGPoint(x: -3, y: -18))
        cg.addLine(to: CGPoint(x: 1, y: -18))
        cg.closePath()
        cg.fillPath()
        cg.restoreGState()

        // Tail
        strokeBezier(cg, color: furDark, width: 6,
                     from: CGPoint(x: -14, y: 4),
                     control: CGPoint(x: -22, y: -4),
                     to: CGPoint(x: -18, y: -14))
        // Body
        fillEllipse(cg, cx: 0, cy: 6, rx: 16, ry: 13, color: fur)
        fillEllipse(cg, cx: 3, cy: 9, rx: 13, ry: 10,
                    color: furDark.withAlphaComponent(0.3))
        // Cloak
        let cloakPath = CGMutablePath()
        cloakPath.move(to: CGPoint(x: -13, y: -2))
        cloakPath.addQuadCurve(to: CGPoint(x: 14, y: -2), control: CGPoint(x: 0, y: -6))
        cloakPath.addLine(to: CGPoint(x: 16, y: 18))
        cloakPath.addQuadCurve(to: CGPoint(x: -16, y: 18), control: CGPoint(x: 0, y: 24))
        cloakPath.closeSubpath()
        cg.addPath(cloakPath)
        cg.setFillColor(cloak.cgColor)
        cg.fillPath()
        // Front legs
        fillEllipse(cg, cx: -5, cy: 24, rx: 4, ry: 6, color: fur)
        fillEllipse(cg, cx: 6, cy: 25, rx: 4, ry: 6, color: fur)
        // Big bow out to the right
        cg.saveGState()
        cg.translateBy(x: 18, y: 2)
        // Bow limb
        cg.setStrokeColor(hex(0x4a2d18).cgColor)
        cg.setLineWidth(5)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: 0, y: -14))
        cg.addQuadCurve(to: CGPoint(x: 0, y: 14), control: CGPoint(x: 14, y: 0))
        cg.strokePath()
        cg.setStrokeColor(hex(0x8c5a30).cgColor)
        cg.setLineWidth(2.5)
        cg.beginPath()
        cg.move(to: CGPoint(x: 0, y: -14))
        cg.addQuadCurve(to: CGPoint(x: 0, y: 14), control: CGPoint(x: 14, y: 0))
        cg.strokePath()
        // Bowstring
        cg.setStrokeColor(hex(0xf0e0b0).cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: 0, y: -14))
        cg.addLine(to: CGPoint(x: -3, y: 0))
        cg.addLine(to: CGPoint(x: 0, y: 14))
        cg.strokePath()
        // Arrow shaft
        cg.setStrokeColor(hex(0xc08a50).cgColor)
        cg.setLineWidth(2)
        cg.move(to: CGPoint(x: -6, y: 0))
        cg.addLine(to: CGPoint(x: 12, y: 0))
        cg.strokePath()
        // Arrowhead
        cg.setFillColor(hex(0xe8b94a).cgColor)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.3)
        cg.beginPath()
        cg.move(to: CGPoint(x: 12, y: 0))
        cg.addLine(to: CGPoint(x: 9, y: -2.5))
        cg.addLine(to: CGPoint(x: 9, y: 2.5))
        cg.closePath()
        cg.drawPath(using: .fillStroke)
        cg.restoreGState()
        // Head
        drawPlushDogHead(cg, offsetX: 2, offsetY: -12, r: 13, fur: fur, furDark: furDark)
        // Hood on higher levels
        if level >= 2 {
            let hood = CGMutablePath()
            hood.move(to: CGPoint(x: -14 + 2, y: -2 - 12))
            hood.addQuadCurve(to: CGPoint(x: 14 + 2, y: -2 - 12),
                              control: CGPoint(x: 0 + 2, y: -18 - 12))
            hood.addLine(to: CGPoint(x: 12 + 2, y: 4 - 12))
            hood.addLine(to: CGPoint(x: -12 + 2, y: 4 - 12))
            hood.closeSubpath()
            cg.addPath(hood)
            cg.setFillColor(cloak.cgColor)
            cg.fillPath()
        }
    }

    /// Plush dog head — soft rounded shape, closed crescent eyes, smile.
    private static func drawPlushDogHead(_ cg: CGContext, offsetX: CGFloat, offsetY: CGFloat,
                                         r: CGFloat, fur: UIColor, furDark: UIColor) {
        cg.saveGState()
        cg.translateBy(x: offsetX, y: offsetY)
        // Floppy ears behind head
        fillEllipse(cg, cx: -11, cy: -6, rx: 4, ry: 8, color: furDark)
        fillEllipse(cg, cx: 11, cy: -6, rx: 4, ry: 8, color: furDark)
        // Head shadow
        fillEllipse(cg, cx: 0, cy: r * 0.95, rx: r * 0.9, ry: r * 0.18,
                    color: UIColor(white: 0, alpha: 0.18))
        // Head
        fillEllipse(cg, cx: 0, cy: 0, rx: r, ry: r * 0.92, color: fur)
        // Form shadow
        fillEllipse(cg, cx: r * 0.15, cy: r * 0.15, rx: r * 0.85, ry: r * 0.72,
                    color: furDark.withAlphaComponent(0.3))
        // Top highlight
        fillEllipse(cg, cx: -r * 0.25, cy: -r * 0.35, rx: r * 0.55, ry: r * 0.35,
                    color: UIColor.white.withAlphaComponent(0.35))
        // Muzzle
        fillEllipse(cg, cx: 0, cy: r * 0.3, rx: r * 0.55, ry: r * 0.35,
                    color: hex(0xfff2d6).withAlphaComponent(0.9))
        // Cheek blush
        fillEllipse(cg, cx: -r * 0.55, cy: r * 0.25, rx: r * 0.2, ry: r * 0.13,
                    color: hex(0xf4a2b6).withAlphaComponent(0.6))
        fillEllipse(cg, cx: r * 0.55, cy: r * 0.25, rx: r * 0.2, ry: r * 0.13,
                    color: hex(0xf4a2b6).withAlphaComponent(0.6))
        // Nose
        fillEllipse(cg, cx: 0, cy: r * 0.15, rx: r * 0.13, ry: r * 0.1, color: ink)
        // Smile
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(r * 0.08)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -r * 0.2, y: r * 0.35))
        cg.addQuadCurve(to: CGPoint(x: r * 0.2, y: r * 0.35),
                        control: CGPoint(x: 0, y: r * 0.5))
        cg.strokePath()
        // Closed crescent eyes (capybara-reference look)
        cg.setLineWidth(r * 0.1)
        cg.beginPath()
        cg.move(to: CGPoint(x: -r * 0.45, y: -r * 0.05))
        cg.addQuadCurve(to: CGPoint(x: -r * 0.21, y: -r * 0.05),
                        control: CGPoint(x: -r * 0.33, y: -r * 0.2))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: r * 0.2, y: -r * 0.05))
        cg.addQuadCurve(to: CGPoint(x: r * 0.44, y: -r * 0.05),
                        control: CGPoint(x: r * 0.32, y: -r * 0.2))
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Collector Dog (idle-game utility troop)

    /// Plush golden-retriever-ish collector with a satchel on one hip and a
    /// paw-print badge on the chest. No weapon — it's a non-combat unit.
    private static func drawCollectorDog(_ cg: CGContext, level: Int) {
        // Level-scaled coat: lighter at L1, richer gold at higher levels.
        let coats: [(UIColor, UIColor)] = [
            (hex(0xf4c874), hex(0xb88a46)),
            (hex(0xf0bd5a), hex(0xa7762f)),
            (hex(0xe5a63c), hex(0x8a5c1c)),
            (hex(0xcc8f34), hex(0x6e4c1b)),
            (hex(0xb87824), hex(0x593910)),
        ]
        let idx = min(max(level - 1, 0), coats.count - 1)
        let (fur, furDark) = coats[idx]
        let satchel = hex(0x8a5a30)
        let strap = hex(0x4a2d18)

        // Ground shadow
        fillEllipse(cg, cx: 0, cy: 30, rx: 18, ry: 4.5, color: UIColor(white: 0, alpha: 0.3))
        // Back legs
        fillEllipse(cg, cx: -7, cy: 20, rx: 5, ry: 7, color: furDark)
        fillEllipse(cg, cx: 9, cy: 22, rx: 5, ry: 7, color: furDark)
        // Wagging tail
        strokeBezier(cg, color: furDark, width: 6,
                     from: CGPoint(x: -14, y: 4),
                     control: CGPoint(x: -22, y: -4),
                     to: CGPoint(x: -18, y: -14))
        strokeBezier(cg, color: fur, width: 3.3,
                     from: CGPoint(x: -14, y: 4),
                     control: CGPoint(x: -22, y: -4),
                     to: CGPoint(x: -18, y: -14))
        // Body
        fillEllipse(cg, cx: 0, cy: 6, rx: 17, ry: 14, color: fur)
        fillEllipse(cg, cx: 3, cy: 9, rx: 13, ry: 10,
                    color: furDark.withAlphaComponent(0.3))
        // Satchel on left hip
        fillAndStrokeRect(cg, x: -13, y: 4, w: 10, h: 10,
                          fill: satchel, stroke: strap, line: 1.4)
        // Satchel strap across body
        cg.setStrokeColor(strap.cgColor)
        cg.setLineWidth(1.8)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: -10, y: 4))
        cg.addLine(to: CGPoint(x: 6, y: -4))
        cg.strokePath()
        // Paw-print badge on chest
        fillEllipse(cg, cx: 3, cy: 6, rx: 3.5, ry: 3.5, color: hex(0xffd66a))
        cg.setFillColor(strap.cgColor)
        cg.fillEllipse(in: CGRect(x: 1.2, y: 6.8, width: 3.6, height: 2.6))
        cg.fillEllipse(in: CGRect(x: 0.5, y: 4.0, width: 1.2, height: 1.2))
        cg.fillEllipse(in: CGRect(x: 2.4, y: 3.2, width: 1.2, height: 1.2))
        cg.fillEllipse(in: CGRect(x: 4.3, y: 4.0, width: 1.2, height: 1.2))
        // Front legs
        fillEllipse(cg, cx: -5, cy: 24, rx: 4, ry: 6, color: fur)
        fillEllipse(cg, cx: 6, cy: 25, rx: 4, ry: 6, color: fur)
        // Head — reuse the plush head primitive
        drawPlushDogHead(cg, offsetX: 2, offsetY: -12, r: 13, fur: fur, furDark: furDark)
    }

    // MARK: - Basic Cat

    private static func drawBasicCat(_ cg: CGContext) {
        let fur = hex(0xe8835c)
        let furDark = hex(0xb55a38)

        fillEllipse(cg, cx: 0, cy: 30, rx: 17, ry: 4.5, color: UIColor(white: 0, alpha: 0.3))
        fillEllipse(cg, cx: -7, cy: 20, rx: 5, ry: 7, color: furDark)
        fillEllipse(cg, cx: 9, cy: 21, rx: 5, ry: 7, color: furDark)
        // Curled tail
        cg.setStrokeColor(furDark.cgColor)
        cg.setLineWidth(6)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -12, y: 2))
        cg.addCurve(to: CGPoint(x: -9, y: -8),
                    control1: CGPoint(x: -22, y: -8),
                    control2: CGPoint(x: -8, y: -16))
        cg.strokePath()
        // Body
        fillEllipse(cg, cx: 0, cy: 6, rx: 16, ry: 13, color: fur)
        fillEllipse(cg, cx: 3, cy: 9, rx: 13, ry: 10,
                    color: furDark.withAlphaComponent(0.25))
        // Stripes
        cg.setStrokeColor(furDark.withAlphaComponent(0.7).cgColor)
        cg.setLineWidth(2)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -8, y: 2))
        cg.addQuadCurve(to: CGPoint(x: -5, y: 16), control: CGPoint(x: -7, y: 12))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 2, y: 2))
        cg.addQuadCurve(to: CGPoint(x: 5, y: 16), control: CGPoint(x: 3, y: 12))
        cg.strokePath()
        // Front legs
        fillEllipse(cg, cx: -5, cy: 24, rx: 4, ry: 5.5, color: fur)
        fillEllipse(cg, cx: 7, cy: 25, rx: 4, ry: 5.5, color: fur)
        // Head group
        cg.saveGState()
        cg.translateBy(x: 3, y: -12)
        // Pointy ears
        cg.setFillColor(fur.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: -11, y: -4))
        cg.addLine(to: CGPoint(x: -13, y: -15))
        cg.addLine(to: CGPoint(x: -4, y: -9))
        cg.closePath()
        cg.fillPath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 11, y: -6))
        cg.addLine(to: CGPoint(x: 13, y: -15))
        cg.addLine(to: CGPoint(x: 5, y: -10))
        cg.closePath()
        cg.fillPath()
        // Inner ear (pink)
        cg.setFillColor(hex(0xffb39a).cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: -10, y: -6))
        cg.addLine(to: CGPoint(x: -11, y: -12))
        cg.addLine(to: CGPoint(x: -6, y: -9))
        cg.closePath()
        cg.fillPath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 10, y: -8))
        cg.addLine(to: CGPoint(x: 11, y: -13))
        cg.addLine(to: CGPoint(x: 7, y: -10))
        cg.closePath()
        cg.fillPath()
        // Head
        fillEllipse(cg, cx: 0, cy: 0, rx: 13, ry: 12, color: fur)
        fillEllipse(cg, cx: 3, cy: 3, rx: 10, ry: 9,
                    color: furDark.withAlphaComponent(0.2))
        fillEllipse(cg, cx: -3, cy: -3, rx: 7, ry: 4,
                    color: UIColor.white.withAlphaComponent(0.25))
        // Muzzle
        fillEllipse(cg, cx: 1, cy: 4, rx: 7, ry: 4.5, color: hex(0xfff0e0))
        // Triangle nose
        cg.setFillColor(ink.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 1, y: 1))
        cg.addLine(to: CGPoint(x: 3.5, y: 3))
        cg.addLine(to: CGPoint(x: -1.5, y: 3))
        cg.closePath()
        cg.fillPath()
        // Grin with fangs
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.3)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 1, y: 3)); cg.addLine(to: CGPoint(x: 1, y: 5))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 1, y: 5))
        cg.addQuadCurve(to: CGPoint(x: -3, y: 6), control: CGPoint(x: -2, y: 7))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 1, y: 5))
        cg.addQuadCurve(to: CGPoint(x: 5, y: 6), control: CGPoint(x: 4, y: 7))
        cg.strokePath()
        // Fangs
        drawFang(cg, x: -1, y: 5, h: 2, w: 1)
        drawFang(cg, x: 3, y: 5, h: 2, w: -1)
        // Eyes — yellow slits
        fillEllipse(cg, cx: -4, cy: -2, rx: 2.5, ry: 2.8, color: hex(0xfff500))
        fillEllipse(cg, cx: -4, cy: -2, rx: 0.8, ry: 2.6, color: ink)
        fillEllipse(cg, cx: 5, cy: -2, rx: 2.5, ry: 2.8, color: hex(0xfff500))
        fillEllipse(cg, cx: 5, cy: -2, rx: 0.8, ry: 2.6, color: ink)
        // Brows (angry)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.8)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -7, y: -4))
        cg.addQuadCurve(to: CGPoint(x: -1, y: -4), control: CGPoint(x: -4, y: -6))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 2, y: -4))
        cg.addQuadCurve(to: CGPoint(x: 8, y: -4), control: CGPoint(x: 5, y: -6))
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Tank Cat

    private static func drawTankCat(_ cg: CGContext) {
        let fur = hex(0x7a3538)
        let furDark = hex(0x4a1a1d)

        fillEllipse(cg, cx: 0, cy: 36, rx: 26, ry: 6, color: UIColor(white: 0, alpha: 0.35))
        fillEllipse(cg, cx: -12, cy: 24, rx: 8, ry: 10, color: furDark)
        fillEllipse(cg, cx: 14, cy: 26, rx: 8, ry: 10, color: furDark)
        // Stubby tail
        cg.setStrokeColor(furDark.cgColor)
        cg.setLineWidth(9)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -20, y: 4))
        cg.addQuadCurve(to: CGPoint(x: -26, y: -14), control: CGPoint(x: -30, y: -2))
        cg.strokePath()
        // Huge body
        fillEllipse(cg, cx: 0, cy: 6, rx: 26, ry: 19, color: fur)
        fillEllipse(cg, cx: 5, cy: 10, rx: 20, ry: 14,
                    color: furDark.withAlphaComponent(0.25))
        fillEllipse(cg, cx: 0, cy: 14, rx: 15, ry: 10, color: hex(0xa85055))
        // Spiked collar
        let collar = CGMutablePath()
        collar.move(to: CGPoint(x: -16, y: -13))
        collar.addQuadCurve(to: CGPoint(x: 16, y: -13), control: CGPoint(x: 0, y: -18))
        collar.addLine(to: CGPoint(x: 16, y: -6))
        collar.addQuadCurve(to: CGPoint(x: -16, y: -6), control: CGPoint(x: 0, y: -2))
        collar.closeSubpath()
        cg.addPath(collar)
        cg.setFillColor(hex(0x2a1d16).cgColor)
        cg.fillPath()
        // Spikes
        for cx in [-8, 0, 8] as [CGFloat] {
            cg.setFillColor(hex(0xe0e0e0).cgColor)
            cg.setStrokeColor(ink.cgColor)
            cg.setLineWidth(1.3)
            cg.beginPath()
            cg.move(to: CGPoint(x: cx - 3, y: -13))
            cg.addLine(to: CGPoint(x: cx, y: -18))
            cg.addLine(to: CGPoint(x: cx + 3, y: -13))
            cg.closePath()
            cg.drawPath(using: .fillStroke)
        }
        // Front legs
        fillEllipse(cg, cx: -9, cy: 30, rx: 6, ry: 8, color: fur)
        fillEllipse(cg, cx: 11, cy: 31, rx: 6, ry: 8, color: fur)
        // Head
        cg.saveGState()
        cg.translateBy(x: 4, y: -16)
        // Notched ears
        cg.setFillColor(fur.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: -14, y: -4))
        cg.addLine(to: CGPoint(x: -17, y: -16))
        cg.addLine(to: CGPoint(x: -6, y: -10))
        cg.closePath()
        cg.fillPath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 14, y: -6))
        cg.addLine(to: CGPoint(x: 17, y: -17))
        cg.addLine(to: CGPoint(x: 6, y: -12))
        cg.closePath()
        cg.fillPath()
        // Head
        fillEllipse(cg, cx: 0, cy: 0, rx: 15, ry: 14, color: fur)
        fillEllipse(cg, cx: 4, cy: 3, rx: 11, ry: 10,
                    color: furDark.withAlphaComponent(0.25))
        fillEllipse(cg, cx: -5, cy: -4, rx: 8, ry: 5,
                    color: UIColor.white.withAlphaComponent(0.2))
        // Scar
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        cg.setLineWidth(1.5)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: -7, y: -9))
        cg.addLine(to: CGPoint(x: -2, y: -2))
        cg.strokePath()
        // Muzzle
        fillEllipse(cg, cx: 1, cy: 5, rx: 9, ry: 5.5, color: hex(0xf0d8cc))
        // Nose
        cg.setFillColor(ink.cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: 1, y: 1))
        cg.addLine(to: CGPoint(x: 4, y: 4))
        cg.addLine(to: CGPoint(x: -2, y: 4))
        cg.closePath()
        cg.fillPath()
        // Big fangs
        drawFang(cg, x: -2, y: 5, h: 5, w: 2)
        drawFang(cg, x: 4, y: 5, h: 5, w: -2)
        // Angry yellow eyes
        fillEllipse(cg, cx: -5, cy: -1, rx: 2.4, ry: 2.8, color: hex(0xffcc00))
        fillEllipse(cg, cx: -5, cy: -1, rx: 0.9, ry: 2.6, color: ink)
        fillEllipse(cg, cx: 6, cy: -1, rx: 2.4, ry: 2.8, color: hex(0xffcc00))
        fillEllipse(cg, cx: 6, cy: -1, rx: 0.9, ry: 2.6, color: ink)
        // Angry brows
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(2.2)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: -9, y: -4))
        cg.addQuadCurve(to: CGPoint(x: -1, y: -3), control: CGPoint(x: -5, y: -7))
        cg.strokePath()
        cg.beginPath()
        cg.move(to: CGPoint(x: 2, y: -3))
        cg.addQuadCurve(to: CGPoint(x: 10, y: -4), control: CGPoint(x: 6, y: -7))
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Helpers

    private static func drawFang(_ cg: CGContext, x: CGFloat, y: CGFloat, h: CGFloat, w: CGFloat) {
        cg.setFillColor(UIColor.white.cgColor)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(w > 0 ? 0.6 : 1.3)
        cg.beginPath()
        cg.move(to: CGPoint(x: x, y: y))
        cg.addLine(to: CGPoint(x: x, y: y + h))
        cg.addLine(to: CGPoint(x: x + w, y: y + h - 1))
        cg.closePath()
        cg.drawPath(using: .fillStroke)
    }

    private static func fillEllipse(_ cg: CGContext, cx: CGFloat, cy: CGFloat,
                                     rx: CGFloat, ry: CGFloat, color: UIColor) {
        let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: rect)
    }

    private static func fillAndStrokeRect(_ cg: CGContext, x: CGFloat, y: CGFloat,
                                           w: CGFloat, h: CGFloat,
                                           fill: UIColor, stroke: UIColor, line: CGFloat) {
        let rect = CGRect(x: x, y: y, width: w, height: h)
        cg.setFillColor(fill.cgColor)
        cg.fill(rect)
        cg.setStrokeColor(stroke.cgColor)
        cg.setLineWidth(line)
        cg.stroke(rect)
    }

    private static func strokeBezier(_ cg: CGContext, color: UIColor, width: CGFloat,
                                      from: CGPoint, control: CGPoint, to: CGPoint) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: from)
        cg.addQuadCurve(to: to, control: control)
        cg.strokePath()
    }

    private static func hex(_ rgb: Int) -> UIColor {
        UIColor(red:   CGFloat((rgb >> 16) & 0xff) / 255,
                green: CGFloat((rgb >> 8)  & 0xff) / 255,
                blue:  CGFloat( rgb        & 0xff) / 255,
                alpha: 1)
    }
}

import UIKit
import SpriteKit

/// Bakes a detailed top-down sprite for each `BuildingType` into an `SKTexture`
/// using Core Graphics. Mirrors the JSX reference sprites (`sprites.jsx`) with
/// per-building art — stone bases, roof treatments, emblems, etc. Textures are
/// cached per type and cleared on memory warning via `purgeCache`.
///
/// Uses `UIGraphicsImageRenderer` so coordinates follow SVG-style y-down
/// convention, making direct ports from the JSX SVG paths straightforward.
enum BuildingSprites {
    private static var cache: [BuildingType: SKTexture] = [:]

    static func bodyTexture(for type: BuildingType, in view: SKView) -> SKTexture {
        _ = view // retained for API compatibility; CG renderer is view-independent
        if let cached = cache[type] { return cached }
        let size = BuildingConfig.def(for: type).worldSize
        let texture = bake(type: type, size: size)
        cache[type] = texture
        return texture
    }

    static func purgeCache() { cache.removeAll(keepingCapacity: false) }

    // MARK: - Bake

    private static func bake(type: BuildingType, size: CGSize) -> SKTexture {
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = max(UIScreen.main.scale, 2)  // crisp on 2x/3x, baked once
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let image = renderer.image { ctx in
            dispatch(type: type, in: ctx.cgContext, size: size)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    fileprivate static func dispatch(type: BuildingType, in cg: CGContext, size: CGSize) {
        switch type {
        case .dogHQ:          drawDogHQ(cg, size: size)
        case .trainingCamp:   drawTrainingCamp(cg, size: size)
        case .fort:           drawFort(cg, size: size)
        case .wall:           drawWall(cg, size: size)
        case .waterWell:      drawWaterWell(cg, size: size)
        case .milkFarm:       drawMilkFarm(cg, size: size)
        case .archerTower:    drawArcherTower(cg, size: size)
        case .collectorHouse: drawCollectorHouse(cg, size: size)
        }
    }

    // MARK: - Palette (matches sprites.jsx)

    private static let ink = UIColor(red: 0.16, green: 0.11, blue: 0.09, alpha: 1)
    private static let shadow = UIColor(white: 0, alpha: 0.22)

    // MARK: - Dog HQ (3x2 = 96x64) — stone base, red roof, chevron shingles, paw badge

    private static func drawDogHQ(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 96, sy = H / 64  // scale factors (native JSX is 96x64)

        // Shadow
        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 88*sx, h: 56*sy, r: 4, color: shadow)
        // Stone base
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 88*sx, h: 56*sy, r: 4,
                                 fill: hex(0xc8a876), stroke: ink, line: 2)
        // Red roof
        fillAndStrokeRoundedRect(cg, x: 6*sx, y: 6*sy, w: 80*sx, h: 48*sy, r: 3,
                                 fill: hex(0xe85f3c), stroke: ink, line: 1.8)
        // Chevron shingle stripes (3 rows)
        let chevron = hex(0xc43d3d).cgColor
        cg.setFillColor(chevron)
        for baseY in [14.0, 30.0, 46.0] as [CGFloat] {
            cg.beginPath()
            cg.move(to: CGPoint(x: 6*sx, y: baseY*sy))
            cg.addLine(to: CGPoint(x: 46*sx, y: (baseY - 8)*sy))
            cg.addLine(to: CGPoint(x: 86*sx, y: baseY*sy))
            cg.addLine(to: CGPoint(x: 86*sx, y: (baseY + 6)*sy))
            cg.addLine(to: CGPoint(x: 46*sx, y: (baseY - 2)*sy))
            cg.addLine(to: CGPoint(x: 6*sx, y: (baseY + 6)*sy))
            cg.closePath()
            cg.fillPath()
        }
        // Paw badge
        fillAndStrokeEllipse(cg, cx: 46*sx, cy: 30*sy, rx: 11, ry: 11,
                             fill: hex(0xffd66a), stroke: ink, line: 2)
        // Paw shape (ellipse + 3 pads) — scale 0.55
        let pawS: CGFloat = 0.55
        fillEllipse(cg, cx: 46*sx, cy: (32 + 2*pawS)*sy, rx: 5*pawS, ry: 4*pawS, color: ink)
        fillEllipse(cg, cx: (46 - 5*pawS)*sx, cy: (32 - 3*pawS)*sy, rx: 2*pawS, ry: 2*pawS, color: ink)
        fillEllipse(cg, cx: 46*sx, cy: (32 - 5*pawS)*sy, rx: 2*pawS, ry: 2*pawS, color: ink)
        fillEllipse(cg, cx: (46 + 5*pawS)*sx, cy: (32 - 3*pawS)*sy, rx: 2*pawS, ry: 2*pawS, color: ink)
        // Flag at top-right (clip-free since renderer extends to size bounds)
        fillEllipse(cg, cx: 82*sx, cy: 8*sy, rx: 2, ry: 2, color: ink)
        cg.setFillColor(hex(0xf5c53c).cgColor)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.4)
        cg.beginPath()
        cg.move(to: CGPoint(x: 82*sx, y: 8*sy))
        cg.addLine(to: CGPoint(x: 82*sx, y: max(2, 2*sy)))  // clamp so it stays in bounds
        cg.addLine(to: CGPoint(x: 92*sx, y: 4*sy))
        cg.closePath()
        cg.drawPath(using: .fillStroke)
    }

    // MARK: - Training Camp (2x2 = 64x64) — wooden planked roof, crossed swords

    private static func drawTrainingCamp(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 64, sy = H / 64

        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 56*sx, h: 56*sy, r: 4, color: shadow)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 56*sx, h: 56*sy, r: 4,
                                 fill: hex(0xcd9756), stroke: ink, line: 2)
        // Wooden roof
        fillAndStrokeRoundedRect(cg, x: 6*sx, y: 6*sy, w: 48*sx, h: 48*sy, r: 3,
                                 fill: hex(0xa06832), stroke: ink, line: 1.5)
        // Plank seams
        cg.setStrokeColor(hex(0x7a4a22).cgColor)
        cg.setLineWidth(1.2)
        for y in [18.0, 30.0, 42.0] as [CGFloat] {
            cg.move(to: CGPoint(x: 6*sx, y: y*sy))
            cg.addLine(to: CGPoint(x: 54*sx, y: y*sy))
        }
        cg.strokePath()
        // Crossed swords badge
        fillAndStrokeEllipse(cg, cx: 30*sx, cy: 30*sy, rx: 12, ry: 12,
                             fill: hex(0xf5c53c), stroke: ink, line: 1.8)
        cg.setLineCap(.round)
        cg.setLineWidth(2.5)
        cg.setStrokeColor(ink.cgColor)
        cg.move(to: CGPoint(x: 22*sx, y: 22*sy))
        cg.addLine(to: CGPoint(x: 38*sx, y: 38*sy))
        cg.strokePath()
        cg.setStrokeColor(hex(0xd4d4d4).cgColor)
        cg.move(to: CGPoint(x: 22*sx, y: 38*sy))
        cg.addLine(to: CGPoint(x: 38*sx, y: 22*sy))
        cg.strokePath()
    }

    // MARK: - Fort (2x2 = 64x64) — stone fortress, battlements, central tower, shield

    private static func drawFort(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 64, sy = H / 64

        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 56*sx, h: 56*sy, r: 2, color: shadow)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 56*sx, h: 56*sy, r: 2,
                                 fill: hex(0xb0ada4), stroke: ink, line: 2)
        // Battlement notches along top edge
        for x in [10.0, 22.0, 34.0, 46.0] as [CGFloat] {
            fillAndStrokeRect(cg, x: x*sx, y: 0, w: 6*sx, h: 6*sy,
                              fill: hex(0xb0ada4), stroke: ink, line: 1.5)
        }
        // Inner courtyard
        fillAndStrokeRect(cg, x: 10*sx, y: 10*sy, w: 40*sx, h: 40*sy,
                          fill: hex(0x8f8a82), stroke: ink, line: 1.5)
        // Central tower
        fillAndStrokeRect(cg, x: 22*sx, y: 22*sy, w: 16*sx, h: 16*sy,
                          fill: hex(0x6a645a), stroke: ink, line: 1.5)
        // Shield emblem
        cg.setFillColor(hex(0xc43d3d).cgColor)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.3)
        cg.beginPath()
        cg.move(to: CGPoint(x: 30*sx, y: 26*sy))
        cg.addLine(to: CGPoint(x: 34*sx, y: 27*sy))
        cg.addLine(to: CGPoint(x: 34*sx, y: 32*sy))
        cg.addQuadCurve(to: CGPoint(x: 30*sx, y: 37*sy), control: CGPoint(x: 34*sx, y: 35*sy))
        cg.addQuadCurve(to: CGPoint(x: 26*sx, y: 32*sy), control: CGPoint(x: 26*sx, y: 35*sy))
        cg.addLine(to: CGPoint(x: 26*sx, y: 27*sy))
        cg.closePath()
        cg.drawPath(using: .fillStroke)
        // Shield cross
        cg.setStrokeColor(hex(0xf5c53c).cgColor)
        cg.setLineWidth(1.1)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 30*sx, y: 29*sy))
        cg.addLine(to: CGPoint(x: 30*sx, y: 34*sy))
        cg.move(to: CGPoint(x: 27*sx, y: 31*sy))
        cg.addLine(to: CGPoint(x: 33*sx, y: 31*sy))
        cg.strokePath()
    }

    // MARK: - Wall (1x1 = 32x32) — brick stone

    private static func drawWall(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 32, sy = H / 32

        fillRoundedRect(cg, x: 3*sx, y: 5*sy, w: 28*sx, h: 26*sy, r: 1, color: shadow)
        fillAndStrokeRect(cg, x: 2*sx, y: 2*sy, w: 28*sx, h: 26*sy,
                          fill: hex(0xb0a89e), stroke: ink, line: 1.6)
        // Brick seams
        cg.setStrokeColor(hex(0x787068).cgColor)
        cg.setLineWidth(0.8)
        // Horizontal courses
        cg.move(to: CGPoint(x: 2*sx, y: 10*sy)); cg.addLine(to: CGPoint(x: 30*sx, y: 10*sy))
        cg.move(to: CGPoint(x: 2*sx, y: 18*sy)); cg.addLine(to: CGPoint(x: 30*sx, y: 18*sy))
        // Staggered verticals
        cg.move(to: CGPoint(x: 16*sx, y: 2*sy));  cg.addLine(to: CGPoint(x: 16*sx, y: 10*sy))
        cg.move(to: CGPoint(x: 8*sx,  y: 10*sy)); cg.addLine(to: CGPoint(x: 8*sx,  y: 18*sy))
        cg.move(to: CGPoint(x: 24*sx, y: 10*sy)); cg.addLine(to: CGPoint(x: 24*sx, y: 18*sy))
        cg.move(to: CGPoint(x: 16*sx, y: 18*sy)); cg.addLine(to: CGPoint(x: 16*sx, y: 28*sy))
        cg.strokePath()
    }

    // MARK: - Water Well (2x2 = 64x64) — SQUARE stone base with round well + wooden canopy

    private static func drawWaterWell(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 64, sy = H / 64

        // Drop shadow under the whole tile
        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 56*sx, h: 56*sy, r: 4, color: shadow)
        // Square stone footprint (so the building reads as 2x2, not stretched)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 60*sx, h: 60*sy, r: 4,
                                 fill: hex(0xa09488), stroke: ink, line: 2)
        // Outer stone ring (circular)
        fillAndStrokeEllipse(cg, cx: 32*sx, cy: 32*sy, rx: 22, ry: 22,
                             fill: hex(0x8c8074), stroke: ink, line: 1.8)
        // Inner stone lip
        fillAndStrokeEllipse(cg, cx: 32*sx, cy: 32*sy, rx: 18, ry: 18,
                             fill: hex(0x6a5f55), stroke: ink, line: 1.2)
        // Water surface
        fillAndStrokeEllipse(cg, cx: 32*sx, cy: 34*sy, rx: 14, ry: 14,
                             fill: hex(0x4fb5ea), stroke: ink, line: 1.3)
        // Ripples
        cg.setStrokeColor(hex(0xcfeaff).cgColor)
        cg.setLineWidth(1.3)
        cg.setLineCap(.round)
        cg.beginPath()
        cg.move(to: CGPoint(x: 22*sx, y: 30*sy))
        cg.addQuadCurve(to: CGPoint(x: 34*sx, y: 30*sy), control: CGPoint(x: 28*sx, y: 27*sy))
        cg.strokePath()
        cg.setLineWidth(1)
        cg.beginPath()
        cg.move(to: CGPoint(x: 28*sx, y: 38*sy))
        cg.addQuadCurve(to: CGPoint(x: 40*sx, y: 38*sy), control: CGPoint(x: 34*sx, y: 36*sy))
        cg.strokePath()
        // Stone highlights (corners of square base)
        fillEllipse(cg, cx: 10*sx, cy: 10*sy, rx: 3.5, ry: 1.8,
                    color: hex(0xc4b8ac).withAlphaComponent(0.8))
        fillEllipse(cg, cx: 54*sx, cy: 54*sy, rx: 2.5, ry: 1.4,
                    color: hex(0xc4b8ac).withAlphaComponent(0.7))
        // Wooden canopy — horizontal beam across the top
        fillAndStrokeRect(cg, x: 6*sx, y: 4*sy, w: 52*sx, h: 5*sy,
                          fill: hex(0x8a5a30), stroke: ink, line: 1.4)
        // Canopy posts (vertical) holding the beam
        fillAndStrokeRect(cg, x: 10*sx, y: 4*sy, w: 4*sx, h: 10*sy,
                          fill: hex(0x6a3f20), stroke: ink, line: 1.2)
        fillAndStrokeRect(cg, x: 50*sx, y: 4*sy, w: 4*sx, h: 10*sy,
                          fill: hex(0x6a3f20), stroke: ink, line: 1.2)
        // Rope hanging down (short stub)
        cg.setStrokeColor(hex(0x5a3820).cgColor)
        cg.setLineWidth(1.6)
        cg.move(to: CGPoint(x: 32*sx, y: 9*sy))
        cg.addLine(to: CGPoint(x: 32*sx, y: 20*sy))
        cg.strokePath()
    }

    // MARK: - Milk Farm (2x1 = 64x32) — CREAM / WHITE barn

    private static func drawMilkFarm(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 64, sy = H / 32

        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 56*sx, h: 26*sy, r: 3, color: shadow)
        // Cream/white base (was red in JSX — user requested cream fill)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 56*sx, h: 26*sy, r: 3,
                                 fill: hex(0xfff4dc), stroke: hex(0xa88d5e), line: 2)
        // Soft roof ridge (horizontal divider)
        cg.setStrokeColor(hex(0xc9a670).cgColor)
        cg.setLineWidth(2)
        cg.move(to: CGPoint(x: 2*sx, y: 15*sy))
        cg.addLine(to: CGPoint(x: 58*sx, y: 15*sy))
        cg.strokePath()
        // Plank grooves (subtle cream-brown)
        cg.setStrokeColor(hex(0xe4cfa0).cgColor)
        cg.setLineWidth(0.9)
        for x in [14.0, 26.0, 34.0, 46.0] as [CGFloat] {
            cg.move(to: CGPoint(x: x*sx, y: 2*sy))
            cg.addLine(to: CGPoint(x: x*sx, y: 15*sy))
            cg.move(to: CGPoint(x: x*sx, y: 15*sy))
            cg.addLine(to: CGPoint(x: x*sx, y: 28*sy))
        }
        cg.strokePath()
        // Milk bottle emblem (white bottle, yellow cap)
        fillAndStrokeRect(cg, x: 26*sx, y: 18*sy, w: 8*sx, h: 8*sy,
                          fill: hex(0xffffff), stroke: hex(0xa88d5e), line: 1.3)
        fillAndStrokeRect(cg, x: 27*sx, y: 17*sy, w: 6*sx, h: 2*sy,
                          fill: hex(0xffd66a), stroke: hex(0xa88d5e), line: 1)
        // Tiny milk splash droplet above the emblem
        fillAndStrokeEllipse(cg, cx: 30*sx, cy: 10*sy, rx: 2, ry: 2.2,
                             fill: hex(0xffffff), stroke: hex(0xa88d5e), line: 0.8)
        // Soft cream highlight bands
        cg.setFillColor(hex(0xffffff).withAlphaComponent(0.45).cgColor)
        cg.fill(CGRect(x: 4*sx, y: 4*sy, width: 52*sx, height: 3*sy))
    }

    // MARK: - Archer Tower (1x2 = 32x64) — stone tower, battlements, crossed arrows

    private static func drawArcherTower(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 32, sy = H / 64

        fillRoundedRect(cg, x: 3*sx, y: 5*sy, w: 28*sx, h: 58*sy, r: 2, color: shadow)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 28*sx, h: 58*sy, r: 2,
                                 fill: hex(0xb0ada4), stroke: ink, line: 2)
        // Battlements along top edge
        for x in [4.0, 12.0, 20.0] as [CGFloat] {
            fillAndStrokeRect(cg, x: x*sx, y: 0, w: 6*sx, h: 6*sy,
                              fill: hex(0xb0ada4), stroke: ink, line: 1.3)
        }
        // Upper platform circle where the archer stands
        fillAndStrokeEllipse(cg, cx: 16*sx, cy: 16*sy, rx: 8, ry: 8,
                             fill: hex(0x8f8a82), stroke: ink, line: 1.5)
        // Crossed arrows
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.5)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 11*sx, y: 13*sy))
        cg.addLine(to: CGPoint(x: 21*sx, y: 19*sy))
        cg.move(to: CGPoint(x: 11*sx, y: 19*sy))
        cg.addLine(to: CGPoint(x: 21*sx, y: 13*sy))
        cg.strokePath()
        // Stone seam lines along the shaft
        cg.setStrokeColor(hex(0x8a8278).cgColor)
        cg.setLineWidth(0.8)
        cg.move(to: CGPoint(x: 2*sx, y: 30*sy));  cg.addLine(to: CGPoint(x: 30*sx, y: 30*sy))
        cg.move(to: CGPoint(x: 2*sx, y: 44*sy));  cg.addLine(to: CGPoint(x: 30*sx, y: 44*sy))
        cg.move(to: CGPoint(x: 16*sx, y: 30*sy)); cg.addLine(to: CGPoint(x: 16*sx, y: 44*sy))
        cg.strokePath()
        // Flag near the bottom
        fillEllipse(cg, cx: 16*sx, cy: 54*sy, rx: 1.5, ry: 1.5, color: ink)
        cg.setFillColor(hex(0xc43d3d).cgColor)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(1.2)
        cg.beginPath()
        cg.move(to: CGPoint(x: 16*sx, y: 54*sy))
        cg.addLine(to: CGPoint(x: 16*sx, y: 48*sy))
        cg.addLine(to: CGPoint(x: 24*sx, y: 51*sy))
        cg.closePath()
        cg.drawPath(using: .fillStroke)
    }

    // MARK: - Collector House (2x2 = 64x64) — tan cottage with paw badge + dog peeking

    private static func drawCollectorHouse(_ cg: CGContext, size: CGSize) {
        let W = size.width, H = size.height
        let sx = W / 64, sy = H / 64

        fillRoundedRect(cg, x: 4*sx, y: 6*sy, w: 56*sx, h: 56*sy, r: 4, color: shadow)
        // Cottage base (warm tan)
        fillAndStrokeRoundedRect(cg, x: 2*sx, y: 2*sy, w: 56*sx, h: 56*sy, r: 4,
                                 fill: hex(0xe8c090), stroke: ink, line: 2)
        // Thatched roof band (upper third)
        fillAndStrokeRoundedRect(cg, x: 6*sx, y: 6*sy, w: 48*sx, h: 18*sy, r: 3,
                                 fill: hex(0xa06838), stroke: ink, line: 1.6)
        // Roof shingles — two thatch strokes
        cg.setStrokeColor(hex(0x7a4a22).cgColor)
        cg.setLineWidth(1.2)
        for y in [12.0, 18.0] as [CGFloat] {
            cg.move(to: CGPoint(x: 6*sx, y: y*sy))
            cg.addLine(to: CGPoint(x: 54*sx, y: y*sy))
        }
        cg.strokePath()
        // Door
        fillAndStrokeRoundedRect(cg, x: 26*sx, y: 30*sy, w: 12*sx, h: 22*sy, r: 3,
                                 fill: hex(0x6a3f20), stroke: ink, line: 1.4)
        // Golden paw badge above door
        fillAndStrokeEllipse(cg, cx: 32*sx, cy: 24*sy, rx: 6, ry: 6,
                             fill: hex(0xffd66a), stroke: ink, line: 1.4)
        // Paw shape on badge
        fillEllipse(cg, cx: 32*sx, cy: 25*sy, rx: 2.6, ry: 2.1, color: ink)
        fillEllipse(cg, cx: 29.5*sx, cy: 22.6*sy, rx: 1.1, ry: 1.1, color: ink)
        fillEllipse(cg, cx: 32*sx,   cy: 21.8*sy, rx: 1.1, ry: 1.1, color: ink)
        fillEllipse(cg, cx: 34.5*sx, cy: 22.6*sy, rx: 1.1, ry: 1.1, color: ink)
        // Flanking windows with warm glow
        fillAndStrokeRect(cg, x: 8*sx,  y: 32*sy, w: 12*sx, h: 12*sy,
                          fill: hex(0xffe08a), stroke: ink, line: 1.3)
        fillAndStrokeRect(cg, x: 44*sx, y: 32*sy, w: 12*sx, h: 12*sy,
                          fill: hex(0xffe08a), stroke: ink, line: 1.3)
        cg.setStrokeColor(ink.cgColor)
        cg.setLineWidth(0.9)
        cg.move(to: CGPoint(x: 14*sx, y: 32*sy)); cg.addLine(to: CGPoint(x: 14*sx, y: 44*sy))
        cg.move(to: CGPoint(x: 8*sx,  y: 38*sy)); cg.addLine(to: CGPoint(x: 20*sx, y: 38*sy))
        cg.move(to: CGPoint(x: 50*sx, y: 32*sy)); cg.addLine(to: CGPoint(x: 50*sx, y: 44*sy))
        cg.move(to: CGPoint(x: 44*sx, y: 38*sy)); cg.addLine(to: CGPoint(x: 56*sx, y: 38*sy))
        cg.strokePath()
        // Flower box tiny accent
        fillEllipse(cg, cx: 10*sx, cy: 47*sy, rx: 1.3, ry: 1.3, color: hex(0xf4a8c8))
        fillEllipse(cg, cx: 14*sx, cy: 47*sy, rx: 1.3, ry: 1.3, color: hex(0xfff500))
        fillEllipse(cg, cx: 50*sx, cy: 47*sy, rx: 1.3, ry: 1.3, color: hex(0xfff500))
        fillEllipse(cg, cx: 54*sx, cy: 47*sy, rx: 1.3, ry: 1.3, color: hex(0xf4a8c8))
    }

    // MARK: - CG drawing helpers

    private static func hex(_ rgb: Int) -> UIColor {
        UIColor(red:   CGFloat((rgb >> 16) & 0xff) / 255,
                green: CGFloat((rgb >> 8)  & 0xff) / 255,
                blue:  CGFloat( rgb        & 0xff) / 255,
                alpha: 1)
    }

    private static func fillRoundedRect(_ cg: CGContext, x: CGFloat, y: CGFloat,
                                         w: CGFloat, h: CGFloat, r: CGFloat, color: UIColor) {
        let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                                cornerRadius: r)
        cg.addPath(path.cgPath)
        cg.setFillColor(color.cgColor)
        cg.fillPath()
    }

    private static func fillAndStrokeRoundedRect(_ cg: CGContext, x: CGFloat, y: CGFloat,
                                                  w: CGFloat, h: CGFloat, r: CGFloat,
                                                  fill: UIColor, stroke: UIColor, line: CGFloat) {
        let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                                cornerRadius: r)
        cg.addPath(path.cgPath)
        cg.setFillColor(fill.cgColor)
        cg.setStrokeColor(stroke.cgColor)
        cg.setLineWidth(line)
        cg.drawPath(using: .fillStroke)
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

    private static func fillEllipse(_ cg: CGContext, cx: CGFloat, cy: CGFloat,
                                     rx: CGFloat, ry: CGFloat, color: UIColor) {
        let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: rect)
    }

    private static func fillAndStrokeEllipse(_ cg: CGContext, cx: CGFloat, cy: CGFloat,
                                              rx: CGFloat, ry: CGFloat,
                                              fill: UIColor, stroke: UIColor, line: CGFloat) {
        let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        cg.setFillColor(fill.cgColor)
        cg.fillEllipse(in: rect)
        cg.setStrokeColor(stroke.cgColor)
        cg.setLineWidth(line)
        cg.strokeEllipse(in: rect)
    }
}

/// Public facade so the Store thumbnail (a `UIImage`, not an `SKTexture`)
/// can reuse the same drawing code without duplicating every path.
enum BuildingSpritesPublicAPI {
    static func draw(type: BuildingType, in cg: CGContext, size: CGSize) {
        BuildingSprites.dispatch(type: type, in: cg, size: size)
    }
}

import SpriteKit

/// Bakes the building-body art (rounded rect with shadow, fill, border, top
/// highlight band) into a single `SKTexture` per building type. The texture is
/// then displayed by an `SKSpriteNode` inside the `Building` node.
///
/// This mirrors `BuildingRenderer._drawBuilding` in the JS reference, minus the
/// emoji and level badge — those stay as live `SKLabelNode`s so they can change
/// per instance (level number, build progress, etc.) without re-baking.
enum BuildingSprites {
    /// Cache keyed by building type. Cleared on memory warning.
    private static var cache: [BuildingType: SKTexture] = [:]

    static func bodyTexture(for type: BuildingType, in view: SKView) -> SKTexture {
        if let cached = cache[type] { return cached }
        let texture = bake(type: type, in: view)
        cache[type] = texture
        return texture
    }

    static func purgeCache() {
        cache.removeAll(keepingCapacity: false)
    }

    private static func bake(type: BuildingType, in view: SKView) -> SKTexture {
        let def = BuildingConfig.def(for: type)
        let size = def.worldSize
        let pad: CGFloat = Constants.tileSize * 0.08
        let cornerRadius: CGFloat = 5
        let inner = CGRect(x: pad, y: pad,
                           width: size.width - pad * 2,
                           height: size.height - pad * 2)

        // Container holds shadow + body + highlight; baked together into one texture.
        let container = SKNode()

        // Drop shadow (offset down + right)
        let shadow = SKShapeNode(rect: inner.offsetBy(dx: 2, dy: -2),
                                 cornerRadius: cornerRadius)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.25)
        shadow.strokeColor = .clear
        container.addChild(shadow)

        // Body
        let body = SKShapeNode(rect: inner, cornerRadius: cornerRadius)
        body.fillColor = def.fillColor.skColor
        body.strokeColor = def.borderColor.skColor
        body.lineWidth = 2
        container.addChild(body)

        // Top highlight band (top 25% of inner area, slightly inset)
        let highlightRect = CGRect(
            x: inner.minX + 2,
            y: inner.maxY - inner.height * 0.25 - 2,
            width: inner.width - 4,
            height: inner.height * 0.25
        )
        let highlight = SKShapeNode(rect: highlightRect, cornerRadius: 4)
        highlight.fillColor = SKColor.white.withAlphaComponent(0.12)
        highlight.strokeColor = .clear
        container.addChild(highlight)

        // Bake everything inside `size`. Crop rect ensures consistent texture bounds.
        let texture = view.texture(from: container, crop: CGRect(origin: .zero, size: size))
            ?? SKTexture()
        texture.filteringMode = .linear
        return texture
    }
}

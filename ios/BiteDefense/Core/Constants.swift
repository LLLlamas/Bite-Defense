import CoreGraphics

enum Constants {
    /// Logical grid dimensions — matches the JS reference (`GRID_SIZE = 30`).
    static let gridCols = 30
    static let gridRows = 30

    /// Tile edge length in points. The JS reference uses a flat top-down grid
    /// (despite the `IsoMath` naming), so tiles are squares of `TILE_SIZE = 32`.
    static let tileSize: CGFloat = 32

    /// Camera zoom limits.
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 3.0
    static let defaultZoom: CGFloat = 1.0

    /// Grass tile palette — direct port of `COLORS.GRASS_1..4` from `Constants.js`.
    static let grassColors: [SKColorRGB] = [
        SKColorRGB(r: 0x4a, g: 0x7c, b: 0x34),
        SKColorRGB(r: 0x52, g: 0x8a, b: 0x38),
        SKColorRGB(r: 0x4e, g: 0x82, b: 0x35),
        SKColorRGB(r: 0x45, g: 0x80, b: 0x30)
    ]

    static let gridLineColor = SKColorRGB(r: 0x3a, g: 0x68, b: 0x28)
    static let mapBorderColor = SKColorRGB(r: 0x2a, g: 0x4a, b: 0x18)
    static let backgroundColor = SKColorRGB(r: 0x24, g: 0x50, b: 0x7c)
}

/// Plain RGB triplet so `Constants` stays a pure-data enum (no SpriteKit dependency
/// in unit tests). Convert to `SKColor` / `UIColor` at the call site.
struct SKColorRGB {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

import CoreGraphics

/// Tile / world / screen coordinate math.
///
/// **Naming note:** kept as `IsoMath` to match the JS reference and the port plan,
/// but the projection is actually a flat top-down grid (`worldX = col * tileSize`).
/// True isometric projection can be layered on later as a rendering pass without
/// touching system code that operates on `(col, row)`.
///
/// **Y axis:** SpriteKit uses +Y up, but the game treats `row 0` as the top of the
/// board. We negate Y when going from cart → world so visual "up" matches the
/// reference layout.
enum IsoMath {
    /// (col, row) → world-space point. World origin (0, 0) is the top-left tile's
    /// bottom-left corner; row increases downward visually (negative Y in SK space).
    @inlinable
    static func cartToWorld(col: Int, row: Int, tileSize: CGFloat = Constants.tileSize) -> CGPoint {
        CGPoint(x: CGFloat(col) * tileSize, y: -CGFloat(row) * tileSize)
    }

    /// World-space point → (col, row) as floating values (caller floors for tile pick).
    @inlinable
    static func worldToCart(_ point: CGPoint, tileSize: CGFloat = Constants.tileSize) -> (col: Double, row: Double) {
        (col: Double(point.x / tileSize), row: Double(-point.y / tileSize))
    }

    /// Snap a world-space point to its containing tile, clamped to the grid bounds.
    /// Returns nil if the point is outside the grid.
    static func tileAt(world point: CGPoint,
                       cols: Int = Constants.gridCols,
                       rows: Int = Constants.gridRows,
                       tileSize: CGFloat = Constants.tileSize) -> (col: Int, row: Int)? {
        let (cf, rf) = worldToCart(point, tileSize: tileSize)
        let col = Int(floor(cf))
        let row = Int(floor(rf))
        guard (0..<cols).contains(col), (0..<rows).contains(row) else { return nil }
        return (col, row)
    }

    /// Center point of the entire grid in world coords. Useful for camera positioning.
    @inlinable
    static func gridCenter(cols: Int = Constants.gridCols,
                           rows: Int = Constants.gridRows,
                           tileSize: CGFloat = Constants.tileSize) -> CGPoint {
        CGPoint(x: CGFloat(cols) * tileSize / 2, y: -CGFloat(rows) * tileSize / 2)
    }

    /// Deterministic per-tile pseudo-random in [0, 1). Direct port of the
    /// `seededRandom(x, y)` helper in `TileRenderer.js` so grass color variation
    /// matches the reference visually.
    static func tileSeed(col: Int, row: Int) -> Double {
        let n = sin(Double(col) * 127.1 + Double(row) * 311.7) * 43758.5453
        return n - floor(n)
    }
}

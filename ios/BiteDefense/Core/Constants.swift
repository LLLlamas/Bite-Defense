import CoreGraphics

enum Constants {
    /// Logical grid dimensions — matches the JS reference implementation.
    static let gridCols = 30
    static let gridRows = 30

    /// Isometric tile dimensions in points. Tuned in M2 against device sizes.
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32
}

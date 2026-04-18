import Foundation

/// Tile-occupancy grid. Mirrors the occupancy half of `Grid.js` — separate
/// from the visual tile map (`IsoTileMap`) so systems can reason about
/// placement without needing the rendering layer.
final class Grid {
    let cols: Int
    let rows: Int
    /// `nil` = empty; otherwise the building ID occupying that tile.
    private var occupancy: [[Int?]]

    init(cols: Int = Constants.gridCols, rows: Int = Constants.gridRows) {
        self.cols = cols
        self.rows = rows
        self.occupancy = Array(repeating: Array(repeating: nil, count: cols),
                               count: rows)
    }

    func inBounds(col: Int, row: Int) -> Bool {
        (0..<cols).contains(col) && (0..<rows).contains(row)
    }

    func isAreaFree(col: Int, row: Int, width: Int, height: Int,
                    ignoring buildingId: Int? = nil) -> Bool {
        for r in row..<(row + height) {
            for c in col..<(col + width) {
                guard inBounds(col: c, row: r) else { return false }
                if let id = occupancy[r][c], id != buildingId { return false }
            }
        }
        return true
    }

    func occupy(col: Int, row: Int, width: Int, height: Int, buildingId: Int) {
        for r in row..<(row + height) {
            for c in col..<(col + width) where inBounds(col: c, row: r) {
                occupancy[r][c] = buildingId
            }
        }
    }

    func free(col: Int, row: Int, width: Int, height: Int) {
        for r in row..<(row + height) {
            for c in col..<(col + width) where inBounds(col: c, row: r) {
                occupancy[r][c] = nil
            }
        }
    }

    func buildingId(at col: Int, row: Int) -> Int? {
        guard inBounds(col: col, row: row) else { return nil }
        return occupancy[row][col]
    }

    /// Wipe all occupancy. Called during save-load to rebuild from models.
    func clear() {
        occupancy = Array(repeating: Array(repeating: nil, count: cols), count: rows)
    }
}

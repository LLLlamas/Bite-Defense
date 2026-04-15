import Foundation

/// A* pathfinding on the occupancy grid. Direct port of `PathfindingSystem.js`.
/// Allows 8-directional movement; the destination tile is always reachable
/// even when occupied (enemies walking onto an HQ tile, for example).
final class PathfindingSystem {
    private unowned let grid: Grid

    init(grid: Grid) {
        self.grid = grid
    }

    struct Step: Equatable { let col: Int; let row: Int }

    func findPath(from start: (col: Int, row: Int),
                  to end:   (col: Int, row: Int),
                  maxIterations: Int = 2000) -> [Step]? {
        let (sc, sr) = start
        let (ec, er) = end
        guard grid.inBounds(col: sc, row: sr),
              grid.inBounds(col: ec, row: er) else { return nil }

        func key(_ c: Int, _ r: Int) -> Int { r * grid.cols + c }
        let endKey = key(ec, er)

        var open: [(col: Int, row: Int, f: Double)] = []
        var closed = Set<Int>()
        var cameFrom: [Int: (col: Int, row: Int)] = [:]
        var g: [Int: Double] = [:]

        g[key(sc, sr)] = 0
        open.append((sc, sr, heuristic(sc, sr, ec, er)))

        var iterations = 0
        while !open.isEmpty, iterations < maxIterations {
            iterations += 1
            // Pop lowest-f node.
            var bestIdx = 0
            for i in 1..<open.count where open[i].f < open[bestIdx].f { bestIdx = i }
            let current = open.remove(at: bestIdx)
            let currentKey = key(current.col, current.row)

            if currentKey == endKey {
                return reconstruct(cameFrom: cameFrom, end: (current.col, current.row))
            }
            closed.insert(currentKey)

            let dirs: [(Int, Int, Double)] = [
                (-1, 0, 1), (1, 0, 1), (0, -1, 1), (0, 1, 1),
                (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414)
            ]
            for (dc, dr, cost) in dirs {
                let nc = current.col + dc
                let nr = current.row + dr
                guard grid.inBounds(col: nc, row: nr) else { continue }
                let nKey = key(nc, nr)
                if closed.contains(nKey) { continue }

                // Destination tile is always enterable (even if occupied).
                let isOccupied = grid.buildingId(at: nc, row: nr) != nil
                if isOccupied && nKey != endKey { continue }

                // For diagonal moves, don't let units squeeze through two corner blockers.
                if dc != 0 && dr != 0 {
                    let a1 = grid.buildingId(at: current.col + dc, row: current.row) != nil
                    let a2 = grid.buildingId(at: current.col, row: current.row + dr) != nil
                    if a1 && a2 { continue }
                }

                let tentG = (g[currentKey] ?? .infinity) + cost
                if tentG < (g[nKey] ?? .infinity) {
                    cameFrom[nKey] = (current.col, current.row)
                    g[nKey] = tentG
                    let f = tentG + heuristic(nc, nr, ec, er)
                    if let i = open.firstIndex(where: { key($0.col, $0.row) == nKey }) {
                        open[i].f = f
                    } else {
                        open.append((nc, nr, f))
                    }
                }
            }
        }
        return nil
    }

    private func heuristic(_ c1: Int, _ r1: Int, _ c2: Int, _ r2: Int) -> Double {
        let dx = Double(abs(c1 - c2))
        let dy = Double(abs(r1 - r2))
        return max(dx, dy) + (sqrt(2.0) - 1) * min(dx, dy)
    }

    private func reconstruct(cameFrom: [Int: (col: Int, row: Int)],
                             end: (col: Int, row: Int)) -> [Step] {
        var path = [Step(col: end.col, row: end.row)]
        func key(_ c: Int, _ r: Int) -> Int { r * grid.cols + c }
        var cur = end
        while let prev = cameFrom[key(cur.col, cur.row)] {
            path.insert(Step(col: prev.col, row: prev.row), at: 0)
            cur = prev
        }
        return path
    }
}

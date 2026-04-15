import XCTest
@testable import BiteDefense

final class PathfindingTests: XCTestCase {
    private var grid: Grid!
    private var path: PathfindingSystem!

    override func setUp() {
        super.setUp()
        grid = Grid(cols: 10, rows: 10)
        path = PathfindingSystem(grid: grid)
    }

    func testStraightPathOnEmptyGrid() {
        let p = path.findPath(from: (0, 0), to: (5, 0))
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.first, .init(col: 0, row: 0))
        XCTAssertEqual(p?.last, .init(col: 5, row: 0))
    }

    func testDiagonalPathIsShorterThanManhattan() {
        let p = path.findPath(from: (0, 0), to: (3, 3))
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.count, 4, "0,0 → 1,1 → 2,2 → 3,3 = 4 steps on an open grid")
    }

    func testWallIsRoutedAround() {
        // Put an obstacle in the middle.
        grid.occupy(col: 2, row: 0, width: 1, height: 3, buildingId: 1)
        let p = path.findPath(from: (0, 0), to: (4, 0))
        XCTAssertNotNil(p)
        // Path must not include any blocked tile.
        for step in p ?? [] {
            if step.col == 2 && step.row < 3 && step.col != 4 {
                XCTFail("Path passes through occupied tile \(step)")
            }
        }
    }

    func testBlockedDestinationIsReachable() {
        // Destination tile occupied — still pathable (matches JS behavior).
        grid.occupy(col: 5, row: 5, width: 1, height: 1, buildingId: 1)
        let p = path.findPath(from: (0, 0), to: (5, 5))
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.last, .init(col: 5, row: 5))
    }

    func testOutOfBoundsReturnsNil() {
        let p = path.findPath(from: (0, 0), to: (20, 20))
        XCTAssertNil(p)
    }
}

import XCTest
import CoreGraphics
@testable import BiteDefense

final class IsoMathTests: XCTestCase {
    func testCartToWorldOrigin() {
        let p = IsoMath.cartToWorld(col: 0, row: 0)
        XCTAssertEqual(p, .zero)
    }

    func testCartToWorldAdvancesByTileSize() {
        let p = IsoMath.cartToWorld(col: 3, row: 2)
        XCTAssertEqual(p.x, 3 * Constants.tileSize, accuracy: 0.001)
        // Y is negated so row 0 sits at the top of the visual board.
        XCTAssertEqual(p.y, -2 * Constants.tileSize, accuracy: 0.001)
    }

    func testWorldToCartRoundTrip() {
        for col in [0, 5, 17, 29] {
            for row in [0, 1, 13, 29] {
                let world = IsoMath.cartToWorld(col: col, row: row)
                let (cf, rf) = IsoMath.worldToCart(world)
                XCTAssertEqual(cf, Double(col), accuracy: 0.0001, "col mismatch for (\(col), \(row))")
                XCTAssertEqual(rf, Double(row), accuracy: 0.0001, "row mismatch for (\(col), \(row))")
            }
        }
    }

    func testTileAtSnapsInteriorPoints() {
        // A point just inside tile (5, 7) should resolve to (5, 7).
        let inside = CGPoint(x: 5 * Constants.tileSize + 4, y: -7 * Constants.tileSize - 4)
        let tile = IsoMath.tileAt(world: inside)
        XCTAssertEqual(tile?.col, 5)
        XCTAssertEqual(tile?.row, 7)
    }

    func testTileAtRejectsOutOfBounds() {
        let outside = CGPoint(x: -10, y: 10) // negative col, positive y → row -1
        XCTAssertNil(IsoMath.tileAt(world: outside))
    }

    func testGridCenterIsHalfTotalExtent() {
        let center = IsoMath.gridCenter()
        XCTAssertEqual(center.x, CGFloat(Constants.gridCols) * Constants.tileSize / 2)
        XCTAssertEqual(center.y, -CGFloat(Constants.gridRows) * Constants.tileSize / 2)
    }

    func testTileSeedIsDeterministic() {
        let a = IsoMath.tileSeed(col: 7, row: 13)
        let b = IsoMath.tileSeed(col: 7, row: 13)
        XCTAssertEqual(a, b)
        XCTAssertGreaterThanOrEqual(a, 0.0)
        XCTAssertLessThan(a, 1.0)
    }
}

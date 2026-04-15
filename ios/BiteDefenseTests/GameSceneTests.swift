import XCTest
@testable import BiteDefense

final class GameSceneTests: XCTestCase {
    func testConstantsHaveExpectedGridDimensions() {
        XCTAssertEqual(Constants.gridCols, 30)
        XCTAssertEqual(Constants.gridRows, 30)
    }

    func testTileDimensionsArePositive() {
        XCTAssertGreaterThan(Constants.tileSize, 0)
    }
}

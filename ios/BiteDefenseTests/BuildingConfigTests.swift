import XCTest
@testable import BiteDefense

final class BuildingConfigTests: XCTestCase {
    func testEveryBuildingTypeHasADefinition() {
        for type in BuildingType.allCases {
            XCTAssertNotNil(BuildingConfig.definitions[type], "Missing def for \(type)")
        }
    }

    func testFootprintsMatchReference() {
        // Spot-check footprints against BuildingConfig.js.
        XCTAssertEqual(BuildingConfig.def(for: .dogHQ).tileWidth, 3)
        XCTAssertEqual(BuildingConfig.def(for: .dogHQ).tileHeight, 2)
        XCTAssertEqual(BuildingConfig.def(for: .wall).tileWidth, 1)
        XCTAssertEqual(BuildingConfig.def(for: .wall).tileHeight, 1)
        XCTAssertEqual(BuildingConfig.def(for: .archerTower).tileWidth, 1)
        XCTAssertEqual(BuildingConfig.def(for: .archerTower).tileHeight, 2)
        XCTAssertEqual(BuildingConfig.def(for: .waterWell).tileWidth, 2)
        XCTAssertEqual(BuildingConfig.def(for: .waterWell).tileHeight, 1)
    }

    func testDogHQIsUnique() {
        XCTAssertTrue(BuildingConfig.def(for: .dogHQ).unique)
        XCTAssertFalse(BuildingConfig.def(for: .wall).unique)
    }

    func testWorldSizeMultipliesTileSize() {
        let hq = BuildingConfig.def(for: .dogHQ)
        XCTAssertEqual(hq.worldSize.width, 3 * Constants.tileSize)
        XCTAssertEqual(hq.worldSize.height, 2 * Constants.tileSize)
    }
}

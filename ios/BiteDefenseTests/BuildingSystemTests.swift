import XCTest
@testable import BiteDefense

final class BuildingSystemTests: XCTestCase {
    private var state: GameState!
    private var grid: Grid!
    private var sys: BuildingSystem!

    override func setUp() {
        super.setUp()
        state = GameState()
        grid = Grid()
        sys = BuildingSystem(state: state, grid: grid)
    }

    func testPlaceWallSucceedsAndDeductsResource() {
        let starting = state.water
        let result = sys.place(type: .wall, col: 0, row: 0, payWith: .water)
        guard case .success(let model) = result else { return XCTFail("Expected success, got \(result)") }
        XCTAssertEqual(model.type, .wall)
        XCTAssertEqual(state.water, starting - BuildingConfig.def(for: .wall).placementCost())
        XCTAssertEqual(state.buildings.count, 1)
        XCTAssertEqual(grid.buildingId(at: 0, row: 0), model.id)
    }

    func testPlacingOnOccupiedTileFails() {
        _ = sys.place(type: .wall, col: 1, row: 1, payWith: .water)
        let again = sys.place(type: .wall, col: 1, row: 1, payWith: .water)
        XCTAssertEqual(again, .occupied)
    }

    func testInsufficientResourceBlocksPlacement() {
        state.water = 0
        state.milk = 0
        let result = sys.place(type: .dogHQ, col: 0, row: 0, payWith: .water)
        XCTAssertEqual(result, .insufficientResource)
        XCTAssertTrue(state.buildings.isEmpty)
    }

    func testUniqueBuildingCannotDuplicate() {
        state.water = 100_000 // enough for HQ + retry
        _ = sys.place(type: .dogHQ, col: 0, row: 0, payWith: .water)
        let dup = sys.place(type: .dogHQ, col: 5, row: 5, payWith: .water)
        XCTAssertEqual(dup, .duplicateUnique)
    }

    func testMoveSucceedsToFreeTileAndUpdatesGrid() {
        guard case .success(let model) = sys.place(type: .waterWell, col: 2, row: 2, payWith: .water) else {
            return XCTFail("place failed")
        }
        let result = sys.move(buildingId: model.id, toCol: 10, toRow: 10)
        XCTAssertEqual(result, .success)
        // Old tiles freed
        XCTAssertNil(grid.buildingId(at: 2, row: 2))
        XCTAssertNil(grid.buildingId(at: 3, row: 2))
        // New tiles occupied
        XCTAssertEqual(grid.buildingId(at: 10, row: 10), model.id)
        XCTAssertEqual(grid.buildingId(at: 11, row: 10), model.id)
    }

    func testMoveBlockedRestoresOriginalOccupancy() {
        guard case .success(let a) = sys.place(type: .wall, col: 5, row: 5, payWith: .water) else {
            return XCTFail("place A failed")
        }
        _ = sys.place(type: .wall, col: 7, row: 7, payWith: .water)
        let result = sys.move(buildingId: a.id, toCol: 7, toRow: 7)
        XCTAssertEqual(result, .occupied)
        // Original tile is still occupied by A.
        XCTAssertEqual(grid.buildingId(at: 5, row: 5), a.id)
    }

    func testRemoveFreesGridAndRefundsHalf() {
        let before = state.water
        let cost = BuildingConfig.def(for: .waterWell).placementCost()
        guard case .success(let model) = sys.place(type: .waterWell, col: 0, row: 0, payWith: .water) else {
            return XCTFail("place failed")
        }
        XCTAssertEqual(state.water, before - cost)
        sys.remove(buildingId: model.id)
        XCTAssertNil(grid.buildingId(at: 0, row: 0))
        XCTAssertNil(grid.buildingId(at: 1, row: 0))
        XCTAssertEqual(state.water, before - cost + cost / 2)
        XCTAssertTrue(state.buildings.isEmpty)
    }

    func testUpgradeWaterWellSpendsDogCoins() {
        state.dogCoins = 50
        guard case .success(let model) = sys.place(type: .waterWell, col: 0, row: 0, payWith: .water) else {
            return XCTFail("place failed")
        }
        let coinsBefore = state.dogCoins
        let cost = BuildingConfig.def(for: .waterWell).upgradeCoinCost(currentLevel: 1) ?? -1
        XCTAssertGreaterThan(cost, 0)
        XCTAssertTrue(sys.upgrade(buildingId: model.id))
        XCTAssertEqual(state.dogCoins, coinsBefore - cost)
        XCTAssertEqual(state.buildings.first?.level, 2)
    }
}

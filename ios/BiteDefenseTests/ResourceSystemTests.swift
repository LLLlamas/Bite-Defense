import XCTest
@testable import BiteDefense

final class ResourceSystemTests: XCTestCase {
    private var state: GameState!
    private var grid: Grid!
    private var buildingSys: BuildingSystem!
    private var sys: ResourceSystem!

    override func setUp() {
        super.setUp()
        state = GameState()
        state.water = 1000
        state.milk = 1000
        state.dogCoins = 1000
        grid = Grid()
        buildingSys = BuildingSystem(state: state, grid: grid)
        sys = ResourceSystem(state: state)
    }

    func testWaterWellGeneratesOverTime() {
        guard case .success = buildingSys.place(type: .waterWell,
                                                col: 2, row: 2,
                                                payWith: .water) else {
            return XCTFail("placement failed")
        }
        let before = state.water
        // Water Well L1 = 5/min = 1/12s/unit. Tick 60 whole seconds → 5 water.
        for _ in 0..<60 { sys.update(dt: 1.0) }
        XCTAssertEqual(state.water - before, 5,
                       "L1 water well should produce 5 water in 60s")
    }

    func testMilkFarmGeneratesAtCorrectRate() {
        guard case .success = buildingSys.place(type: .milkFarm,
                                                col: 5, row: 5,
                                                payWith: .water) else {
            return XCTFail("placement failed")
        }
        let before = state.milk
        // Milk Farm L1 = 3/min. 60s → 3.
        for _ in 0..<60 { sys.update(dt: 1.0) }
        XCTAssertEqual(state.milk - before, 3)
    }

    func testNonGeneratingBuildingProducesNothing() {
        _ = buildingSys.place(type: .wall, col: 0, row: 0, payWith: .water)
        let beforeW = state.water
        let beforeM = state.milk
        for _ in 0..<120 { sys.update(dt: 1.0) }
        XCTAssertEqual(state.water, beforeW)
        XCTAssertEqual(state.milk, beforeM)
    }

    func testStorageCapIsRespected() {
        // Lower HQ storage cap is 500 at HQ L1.
        state.water = state.storageCap - 2
        _ = buildingSys.place(type: .waterWell, col: 0, row: 0, payWith: .water)
        // WaterWell placement cost may have drained water — refill to just under cap.
        state.water = state.storageCap - 2
        for _ in 0..<600 { sys.update(dt: 1.0) }
        XCTAssertEqual(state.water, state.storageCap)
    }

    func testFractionalAccumulationSurvivesSubSecondTicks() {
        _ = buildingSys.place(type: .waterWell, col: 0, row: 0, payWith: .water)
        let before = state.water
        // 60 ticks of 1/60s each should still produce the same as one tick of 1s.
        for _ in 0..<3600 { sys.update(dt: 1.0 / 60.0) }
        XCTAssertEqual(state.water - before, 5 * 60,
                       "60s × 60min/s... err, 60min of ticking should produce 5 × 60 = 300")
    }
}

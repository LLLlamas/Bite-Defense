import XCTest
@testable import BiteDefense

final class WaveSystemTests: XCTestCase {
    private var state: GameState!
    private var grid: Grid!
    private var buildingSys: BuildingSystem!
    private var sys: WaveSystem!

    override func setUp() {
        super.setUp()
        state = GameState()
        state.water = 10_000
        state.milk = 10_000
        grid = Grid()
        buildingSys = BuildingSystem(state: state, grid: grid)
        sys = WaveSystem(state: state)
        _ = buildingSys.place(type: .dogHQ, col: 13, row: 14, payWith: .water)
    }

    func testPhaseStartsInBuilding() {
        XCTAssertEqual(state.phase, .building)
    }

    func testEnterPreBattleSetsPhaseAndCorner() {
        sys.enterPreBattle()
        XCTAssertEqual(state.phase, .preBattle)
        XCTAssertNotNil(state.waveCorner)
        XCTAssertTrue((0...3).contains(state.waveCorner ?? -1))
    }

    func testCancelPreBattleReturnsToBuilding() {
        sys.enterPreBattle()
        sys.cancelPreBattle()
        XCTAssertEqual(state.phase, .building)
        XCTAssertNil(state.waveCorner)
    }

    private func addTroop() {
        let hp = TroopConfig.def(for: .soldier).hp(level: 1)
        state.troops.append(TroopModel(
            id: state.mintTroopId(), type: .soldier, level: 1,
            col: 10.5, row: 11, hp: hp, maxHP: hp,
            state: .garrisoned, fortId: nil, attackCooldown: 0
        ))
    }

    func testDeployFromPreBattleMovesToBattleAndSpawnsEnemies() {
        addTroop()
        sys.enterPreBattle()
        sys.deploy()
        XCTAssertEqual(state.phase, .battle)
        // First spawn happens at delay 0; advance 1 tick.
        sys.update(dt: 0.1)
        XCTAssertFalse(state.enemies.isEmpty,
                       "First enemy should spawn at dt=0 delay")
    }

    func testWaveCompletionWithoutEnemiesReturnsCompletePhase() {
        addTroop()
        sys.enterPreBattle()
        sys.deploy()
        // Simulate enough dt to spawn everyone, then kill them all instantly.
        for _ in 0..<200 { sys.update(dt: 0.5) }
        // Kill any that spawned.
        for i in state.enemies.indices { state.enemies[i].state = .dead }
        sys.update(dt: 0.1)
        XCTAssertEqual(state.phase, .waveComplete)
        XCTAssertNotNil(state.lastWaveReward)
    }

    func testHQDestroyedFailsWave() {
        sys.enterPreBattle()
        sys.deploy()
        // Kill HQ directly.
        if let idx = state.buildings.firstIndex(where: { $0.type == .dogHQ }) {
            state.buildings[idx].hp = 0
        }
        sys.update(dt: 0.1)
        XCTAssertEqual(state.phase, .waveFailed)
    }

    func testDismissWaveResultReturnsToBuilding() {
        state.phase = .waveComplete
        sys.dismissWaveResult()
        XCTAssertEqual(state.phase, .building)
    }
}

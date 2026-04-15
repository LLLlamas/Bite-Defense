import XCTest
@testable import BiteDefense

final class CombatSystemTests: XCTestCase {
    private var state: GameState!
    private var grid: Grid!
    private var sys: CombatSystem!

    override func setUp() {
        super.setUp()
        state = GameState()
        grid = Grid()
        sys = CombatSystem(state: state)
        state.phase = .battle
    }

    private func makeTroop(type: TroopType = .soldier, level: Int = 1,
                           col: Double, row: Double) -> TroopModel {
        let def = TroopConfig.def(for: type)
        let hp = def.hp(level: level)
        return TroopModel(id: state.mintTroopId(), type: type, level: level,
                          col: col, row: row, hp: hp, maxHP: hp,
                          state: .idle, fortId: nil, attackCooldown: 0)
    }

    private func makeEnemy(type: EnemyType = .basicCat,
                           col: Double, row: Double) -> EnemyModel {
        let def = EnemyConfig.def(for: type)
        return EnemyModel(id: state.mintEnemyId(), type: type,
                          col: col, row: row,
                          hp: def.hp, maxHP: def.hp, damage: def.damage,
                          state: .moving, attackCooldown: 0)
    }

    func testTroopInRangeDamagesEnemy() {
        state.troops.append(makeTroop(col: 5, row: 5))
        state.enemies.append(makeEnemy(col: 5.5, row: 5))
        let startHP = state.enemies[0].hp

        // First tick: cooldown starts at 0 so attack fires immediately.
        sys.update(dt: 0.1)
        XCTAssertLessThan(state.enemies[0].hp, startHP)
    }

    func testEnemyBeelinesTowardNearestTroop() {
        state.troops.append(makeTroop(col: 10, row: 10))
        state.enemies.append(makeEnemy(col: 0, row: 0))
        let startDist = hypot(state.enemies[0].col - 10, state.enemies[0].row - 10)
        sys.update(dt: 1.0)
        let newDist = hypot(state.enemies[0].col - 10, state.enemies[0].row - 10)
        XCTAssertLessThan(newDist, startDist)
    }

    func testEnemyKillsTroopWhenLowHP() {
        var troop = makeTroop(col: 5, row: 5)
        troop.hp = 1
        state.troops.append(troop)
        state.enemies.append(makeEnemy(col: 5.5, row: 5))
        // Enemy attacks immediately (cooldown 0) and deals >=1 damage.
        sys.update(dt: 0.1)
        XCTAssertTrue(state.troops[0].isDead)
    }

    func testDeadEnemyIsRemovedAndAwardsRewards() {
        state.troops.append(makeTroop(col: 5, row: 5))
        var enemy = makeEnemy(col: 5.5, row: 5)
        enemy.hp = 1
        state.enemies.append(enemy)
        let waterBefore = state.water
        sys.update(dt: 0.1)
        XCTAssertTrue(state.enemies.isEmpty, "Dead enemy should be cleaned up")
        XCTAssertGreaterThan(state.water, waterBefore, "Reward should be added")
    }

    func testNoActionWhenNotInBattle() {
        state.phase = .building
        state.troops.append(makeTroop(col: 5, row: 5))
        state.enemies.append(makeEnemy(col: 5.5, row: 5))
        let before = state.enemies[0].hp
        sys.update(dt: 0.2)
        XCTAssertEqual(state.enemies[0].hp, before)
    }
}

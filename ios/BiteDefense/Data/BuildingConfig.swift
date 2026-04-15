import CoreGraphics

enum BuildingType: String, CaseIterable, Codable, Hashable {
    case dogHQ        = "DOG_HQ"
    case trainingCamp = "TRAINING_CAMP"
    case fort         = "FORT"
    case wall         = "WALL"
    case waterWell    = "WATER_WELL"
    case milkFarm     = "MILK_FARM"
    case archerTower  = "ARCHER_TOWER"
}

/// Static design data per building. Direct port of `BuildingConfig.js`.
/// `costs[0]` is the placement cost; `costs[i]` for `i >= 1` is the cost to
/// upgrade *to* level `i + 1` (so `costs[1]` upgrades level 1 → 2).
struct BuildingDef {
    let type: BuildingType
    let displayName: String
    let description: String
    let tileWidth: Int
    let tileHeight: Int
    let emoji: String
    let fillColor: SKColorRGB
    let borderColor: SKColorRGB
    let maxLevel: Int
    let unique: Bool
    let unlockLevel: Int
    /// Cost amounts indexed by upgrade step. Each amount is paid in **either**
    /// water or milk (player picks at the confirm tray).
    let costs: [Int]
    /// Build/upgrade duration in seconds.
    let buildTime: [Int]
    /// True when upgrades cost Dog Coins instead of water/milk.
    let upgradeUsesCoins: Bool
    let upgradeCoinCost: [Int]?

    // MARK: - Economy (water well / milk farm)
    /// Resource this building generates passively, if any.
    let generatesResource: ResourceKind?
    /// Generation rate per **minute** by level index.
    let generationRate: [Int]

    // MARK: - Training Camp
    /// Queue capacity by level index (training camps only).
    let queueSize: [Int]

    // MARK: - Fort
    /// Housing capacity by level index (forts only).
    let troopCapacity: [Int]

    var worldSize: CGSize {
        CGSize(width: CGFloat(tileWidth) * Constants.tileSize,
               height: CGFloat(tileHeight) * Constants.tileSize)
    }

    func placementCost() -> Int { costs.first ?? 0 }

    /// Returns the cost to upgrade *from* `currentLevel` to `currentLevel + 1`.
    /// Returns nil if already at max level.
    func upgradeCost(currentLevel: Int) -> Int? {
        guard currentLevel < maxLevel else { return nil }
        // costs[0] = placement, costs[1] = upgrade to L2, etc.
        guard currentLevel < costs.count else { return nil }
        return costs[currentLevel]
    }

    func upgradeCoinCost(currentLevel: Int) -> Int? {
        guard upgradeUsesCoins, let arr = upgradeCoinCost,
              currentLevel < maxLevel, currentLevel < arr.count else { return nil }
        return arr[currentLevel]
    }

    /// Resource per minute at the given level.
    func generationRate(at level: Int) -> Int {
        guard generatesResource != nil,
              level >= 1, level <= generationRate.count else { return 0 }
        return generationRate[level - 1]
    }

    func queueSize(at level: Int) -> Int {
        guard level >= 1, level <= queueSize.count else { return 5 }
        return queueSize[level - 1]
    }

    func troopCapacity(at level: Int) -> Int {
        guard level >= 1, level <= troopCapacity.count else { return 0 }
        return troopCapacity[level - 1]
    }
}

enum BuildingConfig {
    static let definitions: [BuildingType: BuildingDef] = [
        .dogHQ: BuildingDef(
            type: .dogHQ, displayName: "Dog HQ",
            description: "Your command center. Upgrade to unlock more buildings and storage.",
            tileWidth: 3, tileHeight: 2, emoji: "🏛️",
            fillColor:   SKColorRGB(r: 0xc9, g: 0x8a, b: 0x4c),
            borderColor: SKColorRGB(r: 0x7a, g: 0x4a, b: 0x1e),
            maxLevel: 10, unique: true, unlockLevel: 1,
            costs:     [0, 200, 500, 1200, 3000, 6000, 12000, 25000, 50000, 90000],
            buildTime: [0, 30,  60,  120,  300,  600,  1200,  2400,  4800,  9600],
            upgradeUsesCoins: false, upgradeCoinCost: nil,
            generatesResource: nil, generationRate: [],
            queueSize: [], troopCapacity: []
        ),
        .trainingCamp: BuildingDef(
            type: .trainingCamp, displayName: "Training Camp",
            description: "Trains dog troops. Requires a Fort to house them.",
            tileWidth: 2, tileHeight: 2, emoji: "⚔️",
            fillColor:   SKColorRGB(r: 0x6a, g: 0x8e, b: 0x3a),
            borderColor: SKColorRGB(r: 0x40, g: 0x56, b: 0x1e),
            maxLevel: 5, unique: false, unlockLevel: 1,
            costs:     [100, 250, 600, 1500, 3500],
            buildTime: [30,  60,  120, 300,  600],
            upgradeUsesCoins: true,
            upgradeCoinCost: [0, 10, 25, 50, 100],
            generatesResource: nil, generationRate: [],
            queueSize: [5, 6, 7, 8, 10],
            troopCapacity: []
        ),
        .fort: BuildingDef(
            type: .fort, displayName: "Fort",
            description: "Houses trained soldiers. Each troop uses slots equal to its level.",
            tileWidth: 2, tileHeight: 2, emoji: "🛡️",
            fillColor:   SKColorRGB(r: 0x8a, g: 0x78, b: 0x56),
            borderColor: SKColorRGB(r: 0x4a, g: 0x3e, b: 0x2a),
            maxLevel: 5, unique: false, unlockLevel: 1,
            costs:     [150, 400, 900, 2000, 4500],
            buildTime: [40,  80,  160, 320,  640],
            upgradeUsesCoins: true,
            upgradeCoinCost: [0, 15, 35, 75, 150],
            generatesResource: nil, generationRate: [],
            queueSize: [],
            troopCapacity: [10, 18, 30, 50, 80]
        ),
        .wall: BuildingDef(
            type: .wall, displayName: "Wall",
            description: "Block enemy paths. Upgrade for more durability.",
            tileWidth: 1, tileHeight: 1, emoji: "🧱",
            fillColor:   SKColorRGB(r: 0x9a, g: 0x9a, b: 0x9a),
            borderColor: SKColorRGB(r: 0x55, g: 0x55, b: 0x55),
            maxLevel: 5, unique: false, unlockLevel: 1,
            costs:     [10, 30, 80, 200, 500],
            buildTime: [5,  10, 20, 40,  80],
            upgradeUsesCoins: false, upgradeCoinCost: nil,
            generatesResource: nil, generationRate: [],
            queueSize: [], troopCapacity: []
        ),
        .waterWell: BuildingDef(
            type: .waterWell, displayName: "Water Well",
            description: "Generates water over time. Upgrade with Dog Coins.",
            tileWidth: 2, tileHeight: 1, emoji: "💧",
            fillColor:   SKColorRGB(r: 0x4f, g: 0x8f, b: 0xc8),
            borderColor: SKColorRGB(r: 0x23, g: 0x4e, b: 0x70),
            maxLevel: 5, unique: false, unlockLevel: 1,
            costs:     [50, 150, 400, 1000, 2500],
            buildTime: [20, 40,  80,  160,  320],
            upgradeUsesCoins: true,
            upgradeCoinCost: [0, 8, 20, 40, 80],
            generatesResource: .water,
            generationRate: [5, 10, 18, 30, 50],
            queueSize: [], troopCapacity: []
        ),
        .milkFarm: BuildingDef(
            type: .milkFarm, displayName: "Milk Farm",
            description: "Generates milk over time (~30% slower than water). Upgrade with Dog Coins.",
            tileWidth: 2, tileHeight: 1, emoji: "🥛",
            fillColor:   SKColorRGB(r: 0xf0, g: 0xe0, b: 0xb0),
            borderColor: SKColorRGB(r: 0x9a, g: 0x7e, b: 0x4a),
            maxLevel: 5, unique: false, unlockLevel: 1,
            costs:     [60, 180, 480, 1200, 3000],
            buildTime: [25, 50,  100, 200,  400],
            upgradeUsesCoins: true,
            upgradeCoinCost: [0, 10, 25, 50, 100],
            generatesResource: .milk,
            generationRate: [3, 7, 13, 22, 36],
            queueSize: [], troopCapacity: []
        ),
        .archerTower: BuildingDef(
            type: .archerTower, displayName: "Archer Tower",
            description: "Fires arrows at approaching enemies.",
            tileWidth: 1, tileHeight: 2, emoji: "🏹",
            fillColor:   SKColorRGB(r: 0xc4, g: 0x93, b: 0x3a),
            borderColor: SKColorRGB(r: 0x6b, g: 0x4f, b: 0x10),
            maxLevel: 5, unique: false, unlockLevel: 3,
            costs:     [75, 200, 500, 1200, 3000],
            buildTime: [25, 50,  100, 200,  400],
            upgradeUsesCoins: false, upgradeCoinCost: nil,
            generatesResource: nil, generationRate: [],
            queueSize: [], troopCapacity: []
        )
    ]

    static func def(for type: BuildingType) -> BuildingDef { definitions[type]! }

    /// Stable ordering for the store panel — matches the JS reference's category flow.
    static let storeOrder: [BuildingType] = [
        .dogHQ, .trainingCamp, .fort, .waterWell, .milkFarm, .archerTower, .wall
    ]
}

import CoreGraphics

/// Enum of every building type. Compile-time safety replaces the JS string keys
/// like `'DOG_HQ'`. Add a case here when introducing a new building type.
enum BuildingType: String, CaseIterable, Codable, Hashable {
    case dogHQ        = "DOG_HQ"
    case trainingCamp = "TRAINING_CAMP"
    case fort         = "FORT"
    case wall         = "WALL"
    case waterWell    = "WATER_WELL"
    case milkFarm     = "MILK_FARM"
    case archerTower  = "ARCHER_TOWER"
}

/// Static design data for a building type. Direct port of `BuildingConfig.js`.
/// M3 only needs the visual + footprint fields; cost / build-time / level arrays
/// will land in M4 alongside the placement + upgrade systems.
struct BuildingDef {
    let type: BuildingType
    let displayName: String
    let tileWidth: Int
    let tileHeight: Int
    let emoji: String
    let fillColor: SKColorRGB
    let borderColor: SKColorRGB
    let maxLevel: Int
    let unique: Bool

    /// World-space size of this building's tile footprint.
    var worldSize: CGSize {
        CGSize(width: CGFloat(tileWidth) * Constants.tileSize,
               height: CGFloat(tileHeight) * Constants.tileSize)
    }
}

enum BuildingConfig {
    /// Lookup table — every `BuildingType` has exactly one entry.
    /// Palette values mirror `BUILDING_BG` from `BuildingRenderer.js`.
    static let definitions: [BuildingType: BuildingDef] = [
        .dogHQ: BuildingDef(
            type: .dogHQ, displayName: "Dog HQ",
            tileWidth: 3, tileHeight: 2,
            emoji: "🏛️",
            fillColor:   SKColorRGB(r: 0xc9, g: 0x8a, b: 0x4c),
            borderColor: SKColorRGB(r: 0x7a, g: 0x4a, b: 0x1e),
            maxLevel: 10, unique: true
        ),
        .trainingCamp: BuildingDef(
            type: .trainingCamp, displayName: "Training Camp",
            tileWidth: 2, tileHeight: 2,
            emoji: "⚔️",
            fillColor:   SKColorRGB(r: 0x6a, g: 0x8e, b: 0x3a),
            borderColor: SKColorRGB(r: 0x40, g: 0x56, b: 0x1e),
            maxLevel: 5, unique: false
        ),
        .fort: BuildingDef(
            type: .fort, displayName: "Fort",
            tileWidth: 2, tileHeight: 2,
            emoji: "🛡️",
            fillColor:   SKColorRGB(r: 0x8a, g: 0x78, b: 0x56),
            borderColor: SKColorRGB(r: 0x4a, g: 0x3e, b: 0x2a),
            maxLevel: 5, unique: false
        ),
        .wall: BuildingDef(
            type: .wall, displayName: "Wall",
            tileWidth: 1, tileHeight: 1,
            emoji: "🧱",
            fillColor:   SKColorRGB(r: 0x9a, g: 0x9a, b: 0x9a),
            borderColor: SKColorRGB(r: 0x55, g: 0x55, b: 0x55),
            maxLevel: 5, unique: false
        ),
        .waterWell: BuildingDef(
            type: .waterWell, displayName: "Water Well",
            tileWidth: 2, tileHeight: 1,
            emoji: "💧",
            fillColor:   SKColorRGB(r: 0x4f, g: 0x8f, b: 0xc8),
            borderColor: SKColorRGB(r: 0x23, g: 0x4e, b: 0x70),
            maxLevel: 5, unique: false
        ),
        .milkFarm: BuildingDef(
            type: .milkFarm, displayName: "Milk Farm",
            tileWidth: 2, tileHeight: 1,
            emoji: "🥛",
            fillColor:   SKColorRGB(r: 0xf0, g: 0xe0, b: 0xb0),
            borderColor: SKColorRGB(r: 0x9a, g: 0x7e, b: 0x4a),
            maxLevel: 5, unique: false
        ),
        .archerTower: BuildingDef(
            type: .archerTower, displayName: "Archer Tower",
            tileWidth: 1, tileHeight: 2,
            emoji: "🏹",
            fillColor:   SKColorRGB(r: 0xc4, g: 0x93, b: 0x3a),
            borderColor: SKColorRGB(r: 0x6b, g: 0x4f, b: 0x10),
            maxLevel: 5, unique: false
        )
    ]

    static func def(for type: BuildingType) -> BuildingDef {
        // Force-unwrap is safe — `definitions` is keyed by every case.
        definitions[type]!
    }
}

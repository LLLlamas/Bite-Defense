import SwiftUI

/// Bottom strip — now split into two tabs:
///
/// • **Buildings** — every placeable structure, tapping enters placement mode.
/// • **Troops** — the Collector Dog (idle harvester) lives here. Combat
///   troops still train via Training Camps, but the collector is a premium
///   one-off unit so it's surfaced as a store card for discoverability.
///
/// Every card uses the new plush `ResourceIcon` family and a baked building
/// thumbnail where applicable — no more emoji placeholders.
struct StorePanel: View {
    @Bindable var coordinator: GameCoordinator

    enum Tab: Hashable { case buildings, troops }
    @State private var tab: Tab = .buildings

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    switch tab {
                    case .buildings:
                        ForEach(BuildingConfig.storeOrder, id: \.self) { type in
                            buildingCard(type: type)
                        }
                    case .troops:
                        collectorCard
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(.black.opacity(0.7))
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton("Buildings", systemImage: "house.fill", tag: .buildings)
            tabButton("Troops", systemImage: "pawprint.fill", tag: .troops)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func tabButton(_ label: String, systemImage: String, tag: Tab) -> some View {
        Button {
            tab = tag
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption2)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(tab == tag ? Color.orange.opacity(0.75) : Color.white.opacity(0.1),
                        in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building card

    @ViewBuilder
    private func buildingCard(type: BuildingType) -> some View {
        let def = BuildingConfig.def(for: type)
        let isPlacingThis = coordinator.placement?.type == type
        let isLockedByLevel = coordinator.state.playerLevel < def.unlockLevel
        let existingCount = coordinator.state.buildings.filter { $0.type == type }.count
        let alreadyPlaced = def.unique && existingCount >= 1
        let capReached = def.cappedByHQLevel && existingCount >= max(1, coordinator.state.hqLevel)
        let disabled = isLockedByLevel || alreadyPlaced || capReached
        let highlighted = coordinator.shopHighlightedType == type

        Button {
            if isPlacingThis {
                coordinator.cancelPlacement()
            } else {
                coordinator.enterPlacement(type)
            }
        } label: {
            VStack(spacing: 4) {
                BuildingThumbnail(type: type)
                    .frame(width: 48, height: 36)
                Text(def.displayName).font(.caption2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    DogCoinIcon(size: 10)
                    Text("\(def.placementCost())")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                if def.unique {
                    Text("\(existingCount)/1")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(alreadyPlaced ? .orange : .white.opacity(0.6))
                } else if def.cappedByHQLevel {
                    Text("\(existingCount)/\(max(1, coordinator.state.hqLevel))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(capReached ? .orange : .white.opacity(0.6))
                } else if isLockedByLevel {
                    Text("Lv \(def.unlockLevel)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .frame(width: 80, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(highlighted    ? Color.yellow.opacity(0.32)
                          : isPlacingThis ? Color.yellow.opacity(0.25)
                                          : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(highlighted || isPlacingThis
                            ? Color.yellow
                            : Color.white.opacity(0.18),
                            lineWidth: highlighted ? 3 : (isPlacingThis ? 2 : 1))
            )
            .opacity(disabled ? 0.35 : 1.0)
            .modifier(ShopCardPulse(active: highlighted))
        }
        .buttonStyle(.bouncy)
        .disabled(disabled)
    }

    // MARK: - Collector card

    /// The collector lives under a "Troops" tab because it's trained (not
    /// placed). Combat troops (soldier / archer) continue to come from
    /// Training Camps — this tile is here for the idle-game bonus unit.
    @ViewBuilder
    private var collectorCard: some View {
        let def = TroopConfig.def(for: .collector)
        let locked = coordinator.state.playerLevel < def.unlockLevel
        let hasCamp = coordinator.state.buildings.contains {
            $0.type == .trainingCamp && !$0.isBuilding
        }
        let disabled = locked || !hasCamp

        Button {
            // Tapping routes the player to a training camp so they can queue
            // a collector. If none exists, highlight the camp store card.
            if let camp = coordinator.state.buildings.first(where: {
                $0.type == .trainingCamp && !$0.isBuilding
            }) {
                coordinator.trainingPanelCampId = camp.id
            } else {
                coordinator.highlightStoreItem(.trainingCamp)
            }
        } label: {
            VStack(spacing: 4) {
                PawIcon(size: 30, color: Color(red: 0.95, green: 0.78, blue: 0.45))
                    .frame(width: 48, height: 36)
                Text("Collector Dog").font(.caption2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 3) {
                    DogCoinIcon(size: 10)
                    Text("\(def.trainCost(level: 1))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(locked
                     ? "Lv \(def.unlockLevel)"
                     : (hasCamp ? "+2 💧 +2 🥛/min" : "Needs camp"))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(locked ? .red.opacity(0.8)
                                    : (hasCamp ? .green : .orange))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.25, green: 0.18, blue: 0.1).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(disabled ? Color.white.opacity(0.18)
                                     : Color.yellow.opacity(0.6),
                            lineWidth: disabled ? 1 : 2)
            )
            .opacity(disabled ? 0.55 : 1.0)
        }
        .buttonStyle(.bouncy)
    }
}

/// Conditionally applies a bouncy pulse + yellow glow to a Store card while
/// `active` is true. Kept as a struct so SwiftUI correctly rebuilds the
/// modifier chain when the highlight flips on/off.
private struct ShopCardPulse: ViewModifier {
    let active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && pulse ? 1.08 : 1.0)
            .shadow(color: active ? .yellow.opacity(pulse ? 0.85 : 0.35) : .clear,
                    radius: active ? (pulse ? 14 : 6) : 0)
            .animation(active
                       ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                       : .easeOut(duration: 0.25),
                       value: pulse)
            .onChange(of: active) { _, now in
                pulse = now
            }
            .onAppear { if active { pulse = true } }
    }
}

/// Miniature rendering of a baked building sprite for the store card. Reuses
/// `BuildingSprites` so the thumbnail always matches the in-game art.
struct BuildingThumbnail: View {
    let type: BuildingType

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: Self.thumbnail(for: type))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private static var cache: [BuildingType: UIImage] = [:]

    private static func thumbnail(for type: BuildingType) -> UIImage {
        if let cached = cache[type] { return cached }
        let size = BuildingConfig.def(for: type).worldSize
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            BuildingSpritesPublicAPI.draw(type: type, in: cg, size: size)
        }
        cache[type] = image
        return image
    }
}

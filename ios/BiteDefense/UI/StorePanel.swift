import SwiftUI

/// Bottom strip listing every building you can place. Tapping enters
/// placement mode for that type.
struct StorePanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BuildingConfig.storeOrder, id: \.self) { type in
                    storeButton(for: type)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.black.opacity(0.55))
    }

    @ViewBuilder
    private func storeButton(for type: BuildingType) -> some View {
        let def = BuildingConfig.def(for: type)
        let isPlacingThis = coordinator.placement?.type == type
        let isLockedByLevel = coordinator.state.playerLevel < def.unlockLevel
        let existingCount = coordinator.state.buildings.filter { $0.type == type }.count
        let alreadyPlaced = def.unique && existingCount >= 1
        let capReached = def.cappedByHQLevel && existingCount >= max(1, coordinator.state.hqLevel)
        let disabled = isLockedByLevel || alreadyPlaced || capReached

        Button {
            if isPlacingThis {
                coordinator.cancelPlacement()
            } else {
                coordinator.enterPlacement(type)
            }
        } label: {
            VStack(spacing: 4) {
                Text(def.emoji).font(.title2)
                Text(def.displayName).font(.caption2.bold())
                    .foregroundStyle(.white)
                Text("\(def.placementCost()) 🪙")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                if def.unique {
                    Text("\(existingCount)/1")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(alreadyPlaced ? .orange : .white.opacity(0.6))
                } else if def.cappedByHQLevel {
                    Text("\(existingCount)/\(max(1, coordinator.state.hqLevel))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(capReached ? .orange : .white.opacity(0.6))
                }
            }
            .frame(width: 72, height: 88)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlacingThis ? Color.yellow.opacity(0.25)
                                        : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPlacingThis ? Color.yellow : Color.white.opacity(0.18),
                            lineWidth: isPlacingThis ? 2 : 1)
            )
            .opacity(disabled ? 0.35 : 1.0)
        }
        .buttonStyle(.bouncy)
        .disabled(disabled)
    }
}

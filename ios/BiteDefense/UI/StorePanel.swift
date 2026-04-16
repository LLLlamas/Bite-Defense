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
        let highlighted = coordinator.shopHighlightedType == type

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

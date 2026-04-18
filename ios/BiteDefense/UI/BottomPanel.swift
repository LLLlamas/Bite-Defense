import SwiftUI

/// Bottom toolbar during the idle `.building` phase. Three buttons only —
/// Info, Shop, and Settings. The difficulty chips + "Start Wave" manual
/// trigger have moved under Settings so the main toolbar stays clean.
struct BottomPanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            toolbarIconButton(symbol: "info.circle.fill",
                              label: "Info",
                              tint: .blue,
                              active: coordinator.infoCardVisible) {
                coordinator.toggleInfoCard()
            }
            toolbarIconButton(symbol: "cart.fill",
                              label: "Shop",
                              tint: .orange,
                              active: coordinator.storeOpen) {
                coordinator.toggleStore()
            }
            toolbarIconButton(symbol: "gearshape.fill",
                              label: "Settings",
                              tint: .purple,
                              active: coordinator.settingsOpen) {
                coordinator.toggleSettings()
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.black.opacity(0.55))
    }

    private func toolbarIconButton(symbol: String, label: String,
                                    tint: Color, active: Bool,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption.bold())
                Text(label)
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(active ? tint : tint.opacity(0.7),
                        in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.bouncy)
    }
}

/// Settings panel — difficulty chips, Start Wave Now, Auto-wave toggle,
/// and speed control. Shown above the toolbar when the gear button is tapped.
struct SettingsPanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // Difficulty — tier chips.
            VStack(alignment: .leading, spacing: 4) {
                Text("Difficulty")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                Text("Higher difficulties = shorter peace between waves + bigger rewards.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 6) {
                    ForEach(DifficultyConfig.order, id: \.self) { level in
                        difficultyChip(level: level)
                    }
                }
            }

            Divider().background(.white.opacity(0.2))

            // Auto-wave toggle.
            Toggle(isOn: Binding(
                get: { coordinator.state.autoWaveEnabled },
                set: { _ in coordinator.toggleAutoWaves() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto Waves")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(waveIntervalSummary)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .tint(.orange)

            // Manual trigger — skips the auto-wave countdown.
            Button {
                coordinator.requestStartWave()
                coordinator.closeSettings()
            } label: {
                Label(startWaveLabel, systemImage: "flag.checkered")
                    .font(.callout.bold())
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(14)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.purple.opacity(0.45), lineWidth: 1.2)
        )
        .padding(.horizontal, 12)
    }

    private var header: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.purple)
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button {
                coordinator.closeSettings()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    private var startWaveLabel: String {
        if coordinator.state.waveStreak > 0 {
            return "Start Now · Wave \(coordinator.state.currentWave + 1)"
        }
        return "Start Wave Now"
    }

    private var waveIntervalSummary: String {
        let secs = Int(coordinator.state.autoWaveIntervalSeconds)
        let mins = secs / 60
        return coordinator.state.autoWaveEnabled
            ? "Next wave every \(mins) min at this difficulty"
            : "Auto-waves paused — use the manual trigger"
    }

    @ViewBuilder
    private func difficultyChip(level: Int) -> some View {
        let tier = DifficultyConfig.tier(level)
        let unlocked = level <= coordinator.state.maxDifficultyUnlocked
        let selected = coordinator.state.selectedDifficulty == level

        Button {
            coordinator.setDifficulty(level)
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 1) {
                    ForEach(0..<level, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(unlocked ? .yellow : .gray)
                    }
                }
                Text(tier.displayName)
                    .font(.system(size: 10, design: .rounded).bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.orange.opacity(0.35) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.orange : Color.white.opacity(0.15),
                            lineWidth: selected ? 2 : 1)
            )
            .opacity(unlocked ? 1 : 0.35)
        }
        .buttonStyle(.bouncy)
        .disabled(!unlocked)
    }
}

/// Pre-battle overlay — kept for the rare manual path where the player
/// enters `.preBattle` for deliberate positioning. The idle-game auto-wave
/// loop skips this phase entirely.
struct PreBattleBar: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        Group {
            if let target = coordinator.pendingTroopMove {
                confirmMoveBar(target: target)
            } else {
                readyBar
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.black.opacity(0.75))
    }

    private var readyBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Position your troops")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                Text("Tap a dog, then a tile to propose a move.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button("Cancel") { coordinator.cancelPreBattle() }
                .buttonStyle(.bordered)
                .tint(.gray)
            Button {
                coordinator.deployBattle()
            } label: {
                Label(coordinator.hasTroops ? "Ready for enemies!" : "Fight Empty",
                      systemImage: "shield.lefthalf.filled")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    @ViewBuilder
    private func confirmMoveBar(target: TilePos) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Move to (\(target.col), \(target.row))?")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                Text("Tap another tile to pick a different spot.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button("Cancel") { coordinator.cancelPendingMove() }
                .buttonStyle(.bordered)
                .tint(.gray)
            Button {
                coordinator.confirmPendingMove()
            } label: {
                Label("Confirm Move", systemImage: "checkmark.circle.fill")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }
}

/// In-battle HUD — live enemy count, wave #, speed control.
struct BattleBar: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wave \(coordinator.state.currentWave)")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Text("Cats \(aliveEnemyCount)")
                    Text("·").foregroundStyle(.white.opacity(0.5))
                    Text("Dogs \(aliveTroopCount)")
                    if let hp = coordinator.state.hq?.hp,
                       let maxHP = coordinator.state.hq?.maxHP, maxHP > 0 {
                        Text("·").foregroundStyle(.white.opacity(0.5))
                        Text("HQ \(hp)/\(maxHP)")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            }
            Spacer()
            Button {
                coordinator.cycleBattleSpeed()
            } label: {
                Text(speedLabel)
                    .font(.caption.bold())
                    .frame(width: 40, height: 28)
                    .background(Color.orange.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.75))
    }

    private var aliveEnemyCount: Int {
        coordinator.state.enemies.filter { !$0.isDead }.count
    }
    private var aliveTroopCount: Int {
        coordinator.state.troops.filter { !$0.isDead && $0.state != .garrisoned }.count
    }
    private var speedLabel: String {
        switch coordinator.battleSpeed {
        case 4.0: return "4×"
        case 2.0: return "2×"
        default: return "1×"
        }
    }
}

/// Post-wave success / failure card.
struct WaveResultCard: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        let phase = coordinator.state.phase
        if phase == .waveComplete, let reward = coordinator.state.lastWaveReward {
            successCard(reward: reward)
        } else if phase == .waveFailed, let info = coordinator.state.lastWaveFailInfo {
            failureCard(waterStolen: info.waterStolen, milkStolen: info.milkStolen)
        }
    }

    @ViewBuilder
    private func successCard(reward: WaveReward) -> some View {
        VStack(spacing: 12) {
            Text("🏆 Wave \(coordinator.state.currentWave) Cleared!")
                .font(.title3.bold())
                .foregroundStyle(.yellow)
            HStack(spacing: 20) {
                stat(icon: AnyView(WaterDropIcon(size: 22)), value: reward.water)
                stat(icon: AnyView(MilkBottleIcon(size: 22)), value: reward.milk)
                stat(icon: AnyView(DogCoinIcon(size: 22)),    value: reward.dogCoins)
                VStack(spacing: 2) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("+\(reward.xp)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.green)
                }
            }
            if coordinator.state.waveStreak > 1 {
                Text("Streak: \(coordinator.state.waveStreak) 🔥")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 10) {
                Button("Go Home") { coordinator.goHome() }
                    .buttonStyle(.bordered).tint(.gray)
                Button {
                    coordinator.dismissWaveResult()
                    coordinator.requestStartWave()
                } label: {
                    Label("Continue (Streak \(coordinator.state.waveStreak + 1))",
                          systemImage: "forward.fill")
                }
                .buttonStyle(.borderedProminent).tint(.green)
            }
        }
        .padding(16)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.yellow.opacity(0.55), lineWidth: 1.5)
        )
        .pulsingGlow(color: .green, min: 6, max: 22, duration: 1.2)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func failureCard(waterStolen: Int, milkStolen: Int) -> some View {
        VStack(spacing: 12) {
            Text("💀 Wave Failed")
                .font(.title3.bold())
                .foregroundStyle(.red)
            Text("The cats broke through and stole:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 20) {
                stat(icon: AnyView(WaterDropIcon(size: 22)), value: -waterStolen)
                stat(icon: AnyView(MilkBottleIcon(size: 22)), value: -milkStolen)
            }
            Button("Retreat to Base") { coordinator.dismissWaveResult() }
                .buttonStyle(.borderedProminent).tint(.red)
        }
        .padding(16)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.red.opacity(0.5), lineWidth: 1.5)
        )
        .pulsingGlow(color: .red, min: 4, max: 16, duration: 1.0)
        .padding(.horizontal, 20)
    }

    private func stat(icon: AnyView, value: Int) -> some View {
        VStack(spacing: 2) {
            icon
            Text("\(value >= 0 ? "+" : "")\(value)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(value >= 0 ? .green : .red)
        }
    }
}

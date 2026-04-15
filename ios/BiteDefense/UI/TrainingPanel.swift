import SwiftUI

/// Panel shown when the player taps a Training Camp and chooses "Train".
/// Lists available troops with cost + time, and shows the current queue.
struct TrainingPanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        if let campId = coordinator.trainingPanelCampId,
           let camp = coordinator.state.buildings.first(where: { $0.id == campId }),
           camp.type == .trainingCamp {
            panel(for: camp)
        }
    }

    @ViewBuilder
    private func panel(for camp: BuildingModel) -> some View {
        let queue = coordinator.state.trainingQueues[camp.id] ?? []
        let queueCap = camp.def.queueSize(at: camp.level)
        let available = coordinator.state.fortAvailableSlots
        let total = coordinator.state.fortTotalCapacity

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("⚔️ Training Camp · Lv \(camp.level)")
                    .font(.headline).foregroundStyle(.white)
                Spacer()
                Text("Queue \(queue.count)/\(queueCap)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text("Fort slots: \(available)/\(total) available")
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 10) {
                ForEach(TroopConfig.order, id: \.self) { type in
                    troopButton(type: type, camp: camp,
                                queueFull: queue.count >= queueCap)
                }
            }

            if !queue.isEmpty {
                Divider().background(.white.opacity(0.25))
                queueView(queue: queue)
            }

            HStack {
                Spacer()
                Button("Close") { coordinator.closeTrainingPanel() }
                    .buttonStyle(.borderedProminent).tint(.gray)
            }
        }
        .padding(12)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func troopButton(type: TroopType, camp: BuildingModel, queueFull: Bool) -> some View {
        let def = TroopConfig.def(for: type)
        let level = camp.level
        let cost = def.trainCost(level: level)
        let time = def.trainTime(level: level)
        let canAfford = coordinator.state.canAffordFlex(cost)
        let hasFortSpace = coordinator.state.fortAvailableSlots >= level
        let disabled = queueFull || !canAfford || !hasFortSpace

        Button {
            _ = coordinator.queueTroop(type)
        } label: {
            VStack(spacing: 3) {
                Text(def.emoji).font(.title2)
                Text(def.displayName).font(.caption2.bold())
                    .foregroundStyle(.white)
                Text("\(cost) 💧/🥛")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                Text(timeString(time))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(disabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    @ViewBuilder
    private func queueView(queue: [TrainingQueueItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(queue.enumerated()), id: \.element.id) { idx, item in
                let def = TroopConfig.def(for: item.troopType)
                HStack(spacing: 8) {
                    Text(def.emoji)
                    Text(def.displayName)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            if idx == 0 {
                                Capsule().fill(Color.green.opacity(0.8))
                                    .frame(width: geo.size.width * item.progress)
                            }
                        }
                    }
                    .frame(height: 5)
                    Text(timeString(max(0, item.timeRemaining)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Button {
                        coordinator.cancelTrainingQueueItem(index: idx)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        if s < 60 { return "\(s)s" }
        return String(format: "%dm %02ds", s / 60, s % 60)
    }
}

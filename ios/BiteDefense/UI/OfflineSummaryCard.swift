import SwiftUI

/// Welcome-back overlay shown once on launch if offline catch-up applied any
/// progress. Tapping "Claim" dismisses; the resources are already in the
/// player's pool by the time this shows.
struct OfflineSummaryCard: View {
    let summary: OfflineSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("🐾 Welcome Back!")
                .font(.title3.bold())
                .foregroundStyle(.yellow)
            Text("You were away for \(summary.elapsedLabel).")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 22) {
                if summary.waterGained > 0 {
                    rewardStat(icon: AnyView(WaterDropIcon(size: 22)),
                               amount: summary.waterGained)
                }
                if summary.milkGained > 0 {
                    rewardStat(icon: AnyView(MilkBottleIcon(size: 22)),
                               amount: summary.milkGained)
                }
                if summary.coinsGained > 0 {
                    rewardStat(icon: AnyView(DogCoinIcon(size: 22)),
                               amount: summary.coinsGained)
                }
            }
            if summary.isEmpty {
                Text("Your camp was quiet while you were away.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Button {
                onDismiss()
            } label: {
                Text(summary.isEmpty ? "OK" : "Claim")
                    .font(.callout.bold())
                    .frame(minWidth: 120, minHeight: 36)
                    .background(Color.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.55), lineWidth: 1.5)
        )
        .padding(.horizontal, 24)
    }

    private func rewardStat(icon: AnyView, amount: Int) -> some View {
        VStack(spacing: 4) {
            icon
            Text("+\(amount)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.green)
        }
    }
}

import SwiftUI

/// Celebration overlay shown when the player levels up. Bouncing headline,
/// glowing background, and — when relevant — a list of newly unlocked
/// buildings / troops so the player learns what progression actually means.
struct LevelUpCard: View {
    let info: LevelUpInfo
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Glow ring behind the icon.
                Circle()
                    .fill(RadialGradient(colors: [.yellow.opacity(0.55), .clear],
                                         center: .center,
                                         startRadius: 4, endRadius: 80))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.12 : 0.92)
                    .opacity(pulse ? 0.9 : 0.6)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                               value: pulse)
                Text("⭐")
                    .font(.system(size: 72))
                    .shadow(color: .yellow.opacity(0.8), radius: 12)
                    .scaleEffect(appear ? 1.0 : 0.2)
                    .rotationEffect(.degrees(appear ? 0 : -35))
                    .animation(.spring(response: 0.48, dampingFraction: 0.5),
                               value: appear)
            }

            Text("LEVEL UP!")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .orange.opacity(0.8), radius: 6)
                .scaleEffect(appear ? 1.0 : 0.6)
                .animation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.05),
                           value: appear)

            Text("You are now Player Level \(info.newLevel)")
                .font(.headline)
                .foregroundStyle(.white)

            if info.unlocks.isEmpty {
                Text("Keep going — more unlocks coming soon!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔓 New unlocks")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    ForEach(info.unlocks) { unlock in
                        unlockRow(unlock)
                    }
                }
                .padding(10)
                .background(Color.yellow.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                onDismiss()
            } label: {
                Label("Sweet!", systemImage: "hands.sparkles.fill")
                    .font(.callout.bold())
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(20)
        .frame(maxWidth: 420)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.yellow.opacity(0.7), lineWidth: 2)
        )
        .shadow(color: .yellow.opacity(pulse ? 0.55 : 0.25),
                radius: pulse ? 20 : 10)
        .padding(.horizontal, 24)
        .scaleEffect(appear ? 1.0 : 0.7)
        .opacity(appear ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: appear)
        .onAppear {
            appear = true
            pulse = true
        }
    }

    @ViewBuilder
    private func unlockRow(_ unlock: LevelUpInfo.Unlock) -> some View {
        HStack(spacing: 10) {
            Text(unlock.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text(unlock.name)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                Text(unlock.kind)
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.85))
            }
            Spacer()
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
        }
    }
}

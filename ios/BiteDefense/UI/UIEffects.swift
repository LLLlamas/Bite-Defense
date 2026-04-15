import SwiftUI

/// Shared visual "juice" helpers — button press bounce, pulsing glow on
/// important cards, and a quick pop animation when a value changes.

/// Adds a light scale-down on press so every tap *feels* responsive.
/// Drop-in replacement for `.buttonStyle(.plain)` when you want bounce but
/// want to preserve the label's own styling (chips, icon-buttons, etc).
struct BouncyButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92
    var duration: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: duration, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle { BouncyButtonStyle() }
}

/// Pulsing colored shadow used to draw the eye to important cards / chips.
struct PulsingGlow: ViewModifier {
    var color: Color = .yellow
    var minRadius: CGFloat = 4
    var maxRadius: CGFloat = 14
    var duration: Double = 1.1

    @State private var on = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.7 : 0.25),
                    radius: on ? maxRadius : minRadius)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true),
                       value: on)
            .onAppear { on = true }
    }
}

extension View {
    /// Ambient glow that pulses gently — good for level-up / reward / guidance surfaces.
    func pulsingGlow(color: Color = .yellow,
                     min: CGFloat = 4, max: CGFloat = 14,
                     duration: Double = 1.1) -> some View {
        modifier(PulsingGlow(color: color, minRadius: min,
                             maxRadius: max, duration: duration))
    }

    /// One-shot scale bounce driven by a changing value (e.g. a resource Int).
    /// Every time `value` changes, the view briefly grows and settles back.
    @ViewBuilder
    func popOnChange<V: Equatable>(of value: V,
                                    scale: CGFloat = 1.18) -> some View {
        modifier(PopOnChange(value: value, scale: scale))
    }

    /// Short horizontal wiggle triggered when `trigger` changes. Useful for
    /// "no-good" feedback or to draw attention to a surface.
    func shakeOnChange<V: Equatable>(of trigger: V) -> some View {
        modifier(ShakeOnChange(trigger: trigger))
    }
}

private struct PopOnChange<V: Equatable>: ViewModifier {
    let value: V
    let scale: CGFloat
    @State private var current: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(current)
            .onChange(of: value) { _, _ in
                withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                    current = scale
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                        current = 1.0
                    }
                }
            }
    }
}

private struct ShakeOnChange<V: Equatable>: ViewModifier {
    let trigger: V
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: sin(phase * .pi * 6) * (1 - min(1, phase)) * 8)
            .onChange(of: trigger) { _, _ in
                phase = 0
                withAnimation(.linear(duration: 0.42)) {
                    phase = 1
                }
            }
    }
}

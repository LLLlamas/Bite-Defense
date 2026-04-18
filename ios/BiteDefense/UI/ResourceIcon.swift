import SwiftUI

/// Plush-style SwiftUI icons for in-game resources. Mirrors the JSX sprite
/// reference (WaterDrop, MilkBottle, DogCoin, Bone, PremiumBone) so the HUD,
/// store, and modals all share one visual language instead of falling back
/// to emoji.
///
/// Sized by `size`; every icon is square. Rendered with SwiftUI primitives —
/// gradients + paths — so they're crisp at any scale and tint-able via
/// `foregroundStyle` when needed for a pressed / disabled state.
enum ResourceIconSize {
    static let chip: CGFloat = 18
    static let panel: CGFloat = 24
    static let hero: CGFloat = 44
}

struct WaterDropIcon: View {
    var size: CGFloat = ResourceIconSize.chip
    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let path = Path { p in
                p.move(to: CGPoint(x: s * 0.5, y: s * 0.09))
                p.addQuadCurve(to: CGPoint(x: s * 0.19, y: s * 0.62),
                               control: CGPoint(x: s * 0.22, y: s * 0.35))
                p.addArc(center: CGPoint(x: s * 0.5, y: s * 0.69),
                         radius: s * 0.31,
                         startAngle: .degrees(180),
                         endAngle: .degrees(360),
                         clockwise: false)
                p.addQuadCurve(to: CGPoint(x: s * 0.5, y: s * 0.09),
                               control: CGPoint(x: s * 0.78, y: s * 0.35))
            }
            ctx.fill(path, with: .linearGradient(
                Gradient(colors: [Color(red: 0.61, green: 0.85, blue: 0.96),
                                  Color(red: 0.17, green: 0.56, blue: 0.78)]),
                startPoint: CGPoint(x: s * 0.3, y: s * 0.2),
                endPoint: CGPoint(x: s * 0.8, y: s * 0.9)
            ))
            ctx.stroke(path, with: .color(Color.black.opacity(0.75)),
                       lineWidth: s * 0.06)
            // Glossy highlight
            let hl = Path(ellipseIn: CGRect(x: s * 0.32, y: s * 0.28,
                                             width: s * 0.16, height: s * 0.22))
            ctx.fill(hl, with: .color(Color.white.opacity(0.55)))
        }
        .frame(width: size, height: size)
    }
}

struct MilkBottleIcon: View {
    var size: CGFloat = ResourceIconSize.chip
    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            // Bottle body
            let bottle = Path { p in
                p.move(to: CGPoint(x: s * 0.38, y: s * 0.15))
                p.addLine(to: CGPoint(x: s * 0.62, y: s * 0.15))
                p.addLine(to: CGPoint(x: s * 0.62, y: s * 0.28))
                p.addLine(to: CGPoint(x: s * 0.72, y: s * 0.42))
                p.addLine(to: CGPoint(x: s * 0.72, y: s * 0.82))
                p.addQuadCurve(to: CGPoint(x: s * 0.60, y: s * 0.92),
                               control: CGPoint(x: s * 0.72, y: s * 0.92))
                p.addLine(to: CGPoint(x: s * 0.40, y: s * 0.92))
                p.addQuadCurve(to: CGPoint(x: s * 0.28, y: s * 0.82),
                               control: CGPoint(x: s * 0.28, y: s * 0.92))
                p.addLine(to: CGPoint(x: s * 0.28, y: s * 0.42))
                p.addLine(to: CGPoint(x: s * 0.38, y: s * 0.28))
                p.closeSubpath()
            }
            ctx.fill(bottle, with: .linearGradient(
                Gradient(colors: [Color.white, Color(red: 0.91, green: 0.83, blue: 0.65)]),
                startPoint: .init(x: 0, y: 0),
                endPoint: .init(x: s, y: s)))
            ctx.stroke(bottle, with: .color(Color.black.opacity(0.75)),
                       lineWidth: s * 0.06)
            // Yellow cap
            let cap = Path(roundedRect: CGRect(x: s * 0.28, y: s * 0.42,
                                               width: s * 0.44, height: s * 0.13),
                           cornerRadius: s * 0.02)
            ctx.fill(cap, with: .color(Color(red: 1.0, green: 0.81, blue: 0.37)))
            ctx.stroke(cap, with: .color(Color.black.opacity(0.75)),
                       lineWidth: s * 0.05)
            // Milk shine
            let shine = Path(ellipseIn: CGRect(x: s * 0.36, y: s * 0.22,
                                                width: s * 0.08, height: s * 0.05))
            ctx.fill(shine, with: .color(Color.white.opacity(0.8)))
        }
        .frame(width: size, height: size)
    }
}

struct DogCoinIcon: View {
    var size: CGFloat = ResourceIconSize.chip
    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let outer = Path(ellipseIn: CGRect(x: s * 0.08, y: s * 0.08,
                                                width: s * 0.84, height: s * 0.84))
            ctx.fill(outer, with: .linearGradient(
                Gradient(colors: [Color(red: 1.0, green: 0.91, blue: 0.54),
                                  Color(red: 0.85, green: 0.61, blue: 0.13)]),
                startPoint: .init(x: s * 0.25, y: s * 0.25),
                endPoint: .init(x: s * 0.8, y: s * 0.9)
            ))
            ctx.stroke(outer, with: .color(Color.black.opacity(0.75)),
                       lineWidth: s * 0.06)
            // Inner ring
            let inner = Path(ellipseIn: CGRect(x: s * 0.19, y: s * 0.19,
                                                width: s * 0.62, height: s * 0.62))
            ctx.stroke(inner, with: .color(Color.black.opacity(0.55)),
                       lineWidth: s * 0.04)
            // Paw pad — central ellipse + three toes
            let pawColor = Color.black.opacity(0.8)
            let pad = Path(ellipseIn: CGRect(x: s * 0.36, y: s * 0.5,
                                              width: s * 0.28, height: s * 0.22))
            ctx.fill(pad, with: .color(pawColor))
            for x in [0.28, 0.5, 0.72] {
                let toe = Path(ellipseIn: CGRect(x: s * CGFloat(x - 0.06),
                                                  y: s * 0.35,
                                                  width: s * 0.12, height: s * 0.12))
                ctx.fill(toe, with: .color(pawColor))
            }
            // Sparkle
            let sparkle = Path(ellipseIn: CGRect(x: s * 0.24, y: s * 0.24,
                                                  width: s * 0.1, height: s * 0.05))
            ctx.fill(sparkle, with: .color(Color.white.opacity(0.85)))
        }
        .frame(width: size, height: size)
    }
}

struct BoneIcon: View {
    var size: CGFloat = ResourceIconSize.chip
    /// Purple-tinted premium variant when true.
    var premium: Bool = false
    var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            // Rotate slightly for a dynamic look (matches JSX tilt).
            ctx.rotate(by: .degrees(-8))
            ctx.translateBy(x: w * 0.08, y: h * 0.18)
            let s = min(w, h)
            let bonePath = Path { p in
                let top = h * 0.35
                let bot = h * 0.55
                p.move(to: CGPoint(x: s * 0.1, y: (top + bot) / 2))
                // Left lobes
                p.addArc(center: CGPoint(x: s * 0.1, y: top),
                         radius: s * 0.1,
                         startAngle: .degrees(180),
                         endAngle: .degrees(90),
                         clockwise: true)
                p.addLine(to: CGPoint(x: s * 0.8, y: top - s * 0.1))
                p.addArc(center: CGPoint(x: s * 0.8, y: top),
                         radius: s * 0.1,
                         startAngle: .degrees(270),
                         endAngle: .degrees(0),
                         clockwise: false)
                p.addArc(center: CGPoint(x: s * 0.8, y: bot),
                         radius: s * 0.1,
                         startAngle: .degrees(0),
                         endAngle: .degrees(90),
                         clockwise: false)
                p.addLine(to: CGPoint(x: s * 0.1, y: bot + s * 0.1))
                p.addArc(center: CGPoint(x: s * 0.1, y: bot),
                         radius: s * 0.1,
                         startAngle: .degrees(90),
                         endAngle: .degrees(180),
                         clockwise: false)
                p.closeSubpath()
            }
            if premium {
                ctx.fill(bonePath, with: .linearGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.75, blue: 0.92),
                                      Color(red: 0.66, green: 0.30, blue: 0.77)]),
                    startPoint: .init(x: 0, y: 0),
                    endPoint: .init(x: s, y: s)))
            } else {
                ctx.fill(bonePath, with: .linearGradient(
                    Gradient(colors: [Color.white, Color(red: 1.0, green: 0.97, blue: 0.89)]),
                    startPoint: .init(x: 0, y: 0),
                    endPoint: .init(x: 0, y: s)))
            }
            ctx.stroke(bonePath, with: .color(Color.black.opacity(0.75)),
                       lineWidth: s * 0.05)
        }
        .frame(width: size, height: size)
    }
}

/// Paw icon used for the Collector Dog unit slot + shop chip.
struct PawIcon: View {
    var size: CGFloat = ResourceIconSize.chip
    var color: Color = .black.opacity(0.85)
    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let pad = Path(ellipseIn: CGRect(x: s * 0.28, y: s * 0.5,
                                              width: s * 0.44, height: s * 0.36))
            ctx.fill(pad, with: .color(color))
            for (cx, cy, r) in [(0.2, 0.3, 0.14), (0.5, 0.2, 0.14),
                                 (0.8, 0.3, 0.14)] {
                let toe = Path(ellipseIn: CGRect(x: s * (cx - r), y: s * (cy - r),
                                                  width: s * r * 2, height: s * r * 2))
                ctx.fill(toe, with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

extension ResourceKind {
    /// Plush SwiftUI icon matching this resource kind. Use instead of `emoji`.
    @ViewBuilder
    func icon(size: CGFloat = ResourceIconSize.chip) -> some View {
        switch self {
        case .water:    WaterDropIcon(size: size)
        case .milk:     MilkBottleIcon(size: size)
        case .dogCoins: DogCoinIcon(size: size)
        }
    }
}

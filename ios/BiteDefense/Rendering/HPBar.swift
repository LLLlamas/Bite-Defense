import SpriteKit

/// Tiny HP bar above a unit or building. Width is fixed; the fill shrinks.
final class HPBar: SKNode {
    private let background: SKShapeNode
    private let fill: SKShapeNode
    private let barWidth: CGFloat
    private let barHeight: CGFloat = 3

    init(width: CGFloat) {
        self.barWidth = width
        self.background = SKShapeNode(rectOf: CGSize(width: width, height: barHeight),
                                       cornerRadius: 1)
        background.fillColor = SKColor(white: 0, alpha: 0.55)
        background.strokeColor = .clear

        self.fill = SKShapeNode(rectOf: CGSize(width: width, height: barHeight),
                                cornerRadius: 1)
        fill.fillColor = SKColor(red: 0.32, green: 0.82, blue: 0.38, alpha: 1)
        fill.strokeColor = .clear

        super.init()
        addChild(background)
        addChild(fill)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    func update(hp: Int, maxHP: Int) {
        guard maxHP > 0 else { isHidden = true; return }
        let frac = max(0, min(1, CGFloat(hp) / CGFloat(maxHP)))
        if frac >= 0.999 { isHidden = true; return }
        isHidden = false
        fill.xScale = max(0.001, frac)
        fill.position.x = -barWidth / 2 * (1 - frac)
        // Recolor: green → yellow → red based on fraction.
        if frac > 0.6 {
            fill.fillColor = SKColor(red: 0.32, green: 0.82, blue: 0.38, alpha: 1)
        } else if frac > 0.3 {
            fill.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
        } else {
            fill.fillColor = SKColor(red: 0.92, green: 0.32, blue: 0.26, alpha: 1)
        }
    }
}

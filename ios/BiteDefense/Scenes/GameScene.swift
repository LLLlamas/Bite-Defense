import SpriteKit

/// M1: blank scene with a centered tappable label that confirms touch + render are wired up.
/// Replaced in M2 by the real isometric tile map.
final class GameScene: SKScene {
    private var helloLabel: SKLabelNode!
    private var tapCounter = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.18, green: 0.42, blue: 0.22, alpha: 1.0) // grass green

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Hello Bite Defense"
        label.fontSize = 28
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.name = "hello"
        addChild(label)
        helloLabel = label
    }

    override func didChangeSize(_ oldSize: CGSize) {
        helloLabel?.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        tapCounter += 1
        helloLabel.text = "Tapped \(tapCounter)×"
        helloLabel.run(.sequence([
            .scale(to: 1.2, duration: 0.08),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }
}

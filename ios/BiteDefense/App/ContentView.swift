import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text("Bite Defense — M1 skeleton")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 12)
            }
        }
    }
}

#Preview {
    ContentView()
}

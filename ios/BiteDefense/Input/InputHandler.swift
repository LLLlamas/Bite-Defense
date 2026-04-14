import SpriteKit
import UIKit

/// Wires UIKit gesture recognizers on the `SKView` to camera + tap behavior.
/// Pan moves the camera; pinch zooms it (clamped); single-tap converts to a
/// world point → tile coordinate → emits a `GameEvent.tileTapped`.
final class InputHandler: NSObject, UIGestureRecognizerDelegate {
    private weak var view: SKView?
    private weak var scene: SKScene?
    private weak var camera: SKCameraNode?

    private var lastPanTranslation: CGPoint = .zero
    private var pinchStartScale: CGFloat = 1.0

    init(view: SKView, scene: SKScene, camera: SKCameraNode) {
        self.view = view
        self.scene = scene
        self.camera = camera
        super.init()
        installGestures()
    }

    private func installGestures() {
        guard let view else { return }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        // Make sure the pan doesn't swallow taps
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    // Allow simultaneous pan + pinch so two-finger zoom-while-panning feels right.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard let view, let camera else { return }
        switch gr.state {
        case .began:
            lastPanTranslation = .zero
        case .changed:
            let t = gr.translation(in: view)
            let delta = CGPoint(x: t.x - lastPanTranslation.x, y: t.y - lastPanTranslation.y)
            lastPanTranslation = t
            // Camera moves opposite to finger drag; SK has +Y up so invert dy.
            let scale = camera.xScale
            camera.position.x -= delta.x * scale
            camera.position.y += delta.y * scale
            emitMoved()
        default:
            lastPanTranslation = .zero
        }
    }

    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        guard let camera else { return }
        switch gr.state {
        case .began:
            pinchStartScale = camera.xScale
        case .changed:
            // Camera scale is *inverse* of zoom — bigger scale = zoomed out.
            let target = pinchStartScale / gr.scale
            let clamped = max(1 / Constants.maxZoom, min(1 / Constants.minZoom, target))
            camera.setScale(clamped)
            emitMoved()
        default:
            break
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        guard let view, let scene else { return }
        let viewPoint = gr.location(in: view)
        // Convert UIKit point (origin top-left, +Y down) → SK scene point.
        let scenePoint = scene.convertPoint(fromView: viewPoint)
        guard let tile = IsoMath.tileAt(world: scenePoint) else { return }
        EventBus.shared.send(.tileTapped(col: tile.col, row: tile.row))
    }

    private func emitMoved() {
        guard let camera else { return }
        let zoom = 1 / camera.xScale
        EventBus.shared.send(.cameraMoved(position: camera.position, zoom: zoom))
    }
}

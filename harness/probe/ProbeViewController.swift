import UIKit
import MetalKit

final class ProbeViewController: UIViewController {
    private var metalView: MTKView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = MTLCreateSystemDefaultDevice() else {
            print("PROBE_ERROR no Metal device")
            exit(1)
        }

        let mtk = MTKView(frame: view.bounds, device: device)
        mtk.translatesAutoresizingMaskIntoConstraints = false
        mtk.colorPixelFormat = .bgra8Unorm
        mtk.depthStencilPixelFormat = .depth32Float
        mtk.clearDepth = 1.0
        mtk.framebufferOnly = false
        mtk.isPaused = true
        mtk.enableSetNeedsDisplay = false
        view.addSubview(mtk)

        NSLayoutConstraint.activate([
            mtk.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtk.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtk.topAnchor.constraint(equalTo: view.topAnchor),
            mtk.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        metalView = mtk
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let mtk = metalView else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Probe.run(view: mtk)
        }
    }
}

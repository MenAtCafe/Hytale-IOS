import UIKit
import MetalKit

final class ViewController: UIViewController {
    private var renderer: Renderer?
    private let hud = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = MTLCreateSystemDefaultDevice() else {
            HUD.shared.log("no Metal device")
            return
        }

        let mtk = MTKView(frame: .zero, device: device)
        mtk.translatesAutoresizingMaskIntoConstraints = false
        mtk.colorPixelFormat = .bgra8Unorm
        mtk.depthStencilPixelFormat = .depth32Float
        mtk.clearDepth = 1.0
        mtk.clearColor = MTLClearColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        mtk.isPaused = false
        mtk.enableSetNeedsDisplay = false
        mtk.preferredFramesPerSecond = 60

        let r = Renderer(view: mtk)
        mtk.delegate = r
        renderer = r
        view.addSubview(mtk)

        NSLayoutConstraint.activate([
            mtk.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtk.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtk.topAnchor.constraint(equalTo: view.topAnchor),
            mtk.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.numberOfLines = 0
        hud.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        hud.textColor = UIColor(red: 0.6, green: 1.0, blue: 0.7, alpha: 0.9)
        hud.text = "booting..."
        view.addSubview(hud)

        NSLayoutConstraint.activate([
            hud.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            hud.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])

        HUD.shared.onUpdate = { [weak self] text in
            self?.hud.text = text
        }

        let caption = UILabel()
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.text = "Hytale blocks  ·  GL→Metal renderer  ·  depth + cull + indexed"
        caption.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        caption.textColor = UIColor(white: 1.0, alpha: 0.55)
        caption.textAlignment = .center
        view.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            caption.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])
    }
}

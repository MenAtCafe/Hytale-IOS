import Foundation

final class HUD {
    static let shared = HUD()
    var onUpdate: ((String) -> Void)?
    private var lines: [String] = []

    func log(_ s: String) {
        lines.append(s)
        if lines.count > 10 { lines.removeFirst(lines.count - 10) }
        let text = lines.joined(separator: "\n")
        DispatchQueue.main.async { self.onUpdate?(text) }
        print(s)
    }
}

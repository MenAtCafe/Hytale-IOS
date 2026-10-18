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
        NSLog("[hytale] %@", s)
        let path = "/tmp/hytalegl.log"
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile()
            fh.write((s + "\n").data(using: .utf8)!)
            fh.closeFile()
        } else {
            try? (s + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

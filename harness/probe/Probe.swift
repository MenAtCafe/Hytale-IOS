import Foundation
import MetalKit
import CoreGraphics
import ImageIO

struct ProbeReport: Codable {
    struct Draw: Codable {
        var attached: Bool
        var presented: Bool
        var defaultWidth: Int
        var defaultHeight: Int
        var fboStatus: UInt32
        var fboComplete: Bool
        var pixels: Int
        var nonBackground: Int
        var meanRGB: [Double]
        var png: String?
    }

    var total: Int
    var reachable: Int
    var missing: [String]
    var draw: Draw?
    var error: String?
    var elapsedMs: Double
    var logTail: String?
}

enum Probe {
    static let vertexShader = """
    #version 410 core
    layout(location = 0) in vec3 aPos;
    layout(location = 1) in vec3 aColor;
    out vec3 vColor;
    void main() {
        vColor = aColor;
        gl_Position = vec4(aPos, 1.0);
    }
    """

    static let fragmentShader = """
    #version 410 core
    in vec3 vColor;
    out vec4 oColor;
    void main() { oColor = vec4(vColor, 1.0); }
    """

    static func run(view: MTKView) {
        let start = Date()
        var report = ProbeReport(
            total: GLSurface.count, reachable: 0, missing: [],
            draw: nil, error: nil, elapsedMs: 0, logTail: nil
        )

        do {
            let env = try Bootstrap.load()

            for name in GLSurface where GLResolve.symbol(name, env.getProc, UnsafeMutableRawPointer.self) == nil {
                report.missing.append(name)
            }
            report.reachable = report.total - report.missing.count

            report.draw = try render(env, view: view)
        } catch {
            report.error = "\(error)"
        }

        report.elapsedMs = Date().timeIntervalSince(start) * 1000
        if let log = try? String(contentsOfFile: "/tmp/hytalegl.log", encoding: .utf8) {
            report.logTail = String(log.suffix(3000))
        }
        emit(report)
        exit(report.error == nil && (report.draw?.fboComplete ?? false) ? 0 : 1)
    }

    private static func render(_ env: ProbeEnv, view: MTKView) throws -> ProbeReport.Draw {
        guard let gl = GLAPI(env.getProc) else {
            throw ProbeError.fatal("not every entry point the probe needs resolved")
        }

        let attached = Bootstrap.attach(view)
        let program = buildProgram(gl)
        let vao = buildGeometry(gl)

        let w = 256
        let h = 256
        var texture: UInt32 = 0
        gl.genTextures(1, &texture)
        gl.bindTexture(GLConst.TEXTURE_2D, texture)
        gl.texImage2D(GLConst.TEXTURE_2D, 0, GLConst.RGBA8, Int32(w), Int32(h), 0,
                      GLConst.RGBA, GLConst.UNSIGNED_BYTE, nil)

        var fbo: UInt32 = 0
        gl.genFramebuffers(1, &fbo)
        gl.bindFramebuffer(GLConst.FRAMEBUFFER, fbo)
        gl.framebufferTexture2D(GLConst.FRAMEBUFFER, GLConst.COLOR_ATTACHMENT0,
                                GLConst.TEXTURE_2D, texture, 0)
        let status = gl.checkFramebufferStatus(GLConst.FRAMEBUFFER)

        gl.viewport(0, 0, Int32(w), Int32(h))
        gl.clearColor(0.04, 0.05, 0.08, 1.0)
        gl.clear(GLConst.COLOR_BUFFER_BIT)
        gl.useProgram(program)
        gl.bindVertexArray(vao)
        gl.drawArrays(GLConst.TRIANGLES, 0, 3)
        gl.finish()

        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBytes { raw in
            gl.readPixels(0, 0, Int32(w), Int32(h), GLConst.RGBA,
                          GLConst.UNSIGNED_BYTE, raw.baseAddress)
        }

        let br = Int(pixels[0]), bg = Int(pixels[1]), bb = Int(pixels[2])
        var nonBackground = 0
        var sum = [0.0, 0.0, 0.0]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if abs(r - br) + abs(g - bg) + abs(b - bb) > 24 { nonBackground += 1 }
            sum[0] += Double(r); sum[1] += Double(g); sum[2] += Double(b)
        }
        let count = Double(w * h)
        let mean = sum.map { ($0 / count * 100).rounded() / 100 }

        let dir = outputDirectory()
        let png = dir + "/frame.png"
        let wrotePNG = writePNG(pixels, w, h, png)

        let dw = Int(view.drawableSize.width)
        let dh = Int(view.drawableSize.height)
        var presented = false
        if dw > 0 && dh > 0 {
            gl.bindFramebuffer(GLConst.FRAMEBUFFER, 0)
            gl.viewport(0, 0, Int32(dw), Int32(dh))
            gl.clearColor(0.04, 0.05, 0.08, 1.0)
            gl.clear(GLConst.COLOR_BUFFER_BIT)
            gl.useProgram(program)
            gl.bindVertexArray(vao)
            gl.drawArrays(GLConst.TRIANGLES, 0, 3)
            gl.endFrame()
            presented = true
        }

        return ProbeReport.Draw(
            attached: attached, presented: presented,
            defaultWidth: dw, defaultHeight: dh,
            fboStatus: status, fboComplete: status == GLConst.FRAMEBUFFER_COMPLETE,
            pixels: w * h, nonBackground: nonBackground, meanRGB: mean,
            png: wrotePNG ? png : nil
        )
    }

    private static func buildProgram(_ gl: GLAPI) -> UInt32 {
        let vs = compile(gl, GLConst.VERTEX_SHADER, vertexShader)
        let fs = compile(gl, GLConst.FRAGMENT_SHADER, fragmentShader)
        let program = gl.createProgram()
        gl.attachShader(program, vs)
        gl.attachShader(program, fs)
        gl.linkProgram(program)
        return program
    }

    private static func compile(_ gl: GLAPI, _ stage: UInt32, _ source: String) -> UInt32 {
        let shader = gl.createShader(stage)
        let cSource = strdup(source)!
        defer { free(cSource) }
        var pointer: UnsafePointer<CChar>? = UnsafePointer(cSource)
        gl.shaderSource(shader, 1, &pointer, nil)
        gl.compileShader(shader)
        return shader
    }

    private static func buildGeometry(_ gl: GLAPI) -> UInt32 {
        var vao: UInt32 = 0
        gl.genVertexArrays(1, &vao)
        gl.bindVertexArray(vao)

        var vbo: UInt32 = 0
        gl.genBuffers(1, &vbo)
        gl.bindBuffer(GLConst.ARRAY_BUFFER, vbo)

        let vertices: [Float] = [
             0.00,  0.65, 0.0,   1.00, 0.25, 0.20,
            -0.60, -0.45, 0.0,   0.20, 0.90, 0.35,
             0.60, -0.45, 0.0,   0.25, 0.45, 1.00,
        ]
        vertices.withUnsafeBytes { raw in
            gl.bufferData(GLConst.ARRAY_BUFFER, raw.count, raw.baseAddress, GLConst.STATIC_DRAW)
        }

        gl.enableVertexAttribArray(0)
        gl.vertexAttribPointer(0, 3, GLConst.FLOAT, 0, 24, nil)
        gl.enableVertexAttribArray(1)
        gl.vertexAttribPointer(1, 3, GLConst.FLOAT, 0, 24, UnsafeRawPointer(bitPattern: 12))
        return vao
    }

    private static func outputDirectory() -> String {
        let dir = ProcessInfo.processInfo.environment["GLPROBE_OUT"]
            ?? (NSTemporaryDirectory() + "/glprobe")
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    private static func writePNG(_ pixels: [UInt8], _ w: Int, _ h: Int, _ path: String) -> Bool {
        var data = pixels
        return data.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(
                    data: buffer.baseAddress, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue),
                  let image = ctx.makeImage(),
                  let dest = CGImageDestinationCreateWithURL(
                    URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
            else { return false }
            CGImageDestinationAddImage(dest, image, nil)
            return CGImageDestinationFinalize(dest)
        }
    }

    private static func emit(_ report: ProbeReport) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let dir = outputDirectory()
        guard let data = try? encoder.encode(report) else { return }
        try? data.write(to: URL(fileURLWithPath: dir + "/report.json"))
        let line = String(data: data, encoding: .utf8) ?? "{}"
        FileHandle.standardOutput.write(("PROBE_RESULT " + line + "\n").data(using: .utf8)!)
        FileHandle.standardOutput.write(("PROBE_DIR " + dir + "\n").data(using: .utf8)!)
        fflush(stdout)
    }
}

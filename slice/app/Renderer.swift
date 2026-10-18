import UIKit
import MetalKit
import simd

func perspective(_ fovY: Float, _ aspect: Float, _ near: Float = 0.1, _ far: Float = 200) -> simd_float4x4 {
    let y = 1 / tan(fovY * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(columns: (
        SIMD4<Float>(x, 0, 0, 0),
        SIMD4<Float>(0, y, 0, 0),
        SIMD4<Float>(0, 0, z, -1),
        SIMD4<Float>(0, 0, z * near, 0)
    ))
}

func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4<Float>(x, y, z, 1)
    return m
}

func scaleMatrix(_ s: Float) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.0.x = s
    m.columns.1.y = s
    m.columns.2.z = s
    return m
}

func lookAt(_ eye: SIMD3<Float>, _ center: SIMD3<Float>, _ up: SIMD3<Float>) -> simd_float4x4 {
    let f = simd_normalize(center - eye)
    let s = simd_normalize(simd_cross(f, up))
    let u = simd_cross(s, f)
    return simd_float4x4(columns: (
        SIMD4<Float>(s.x, u.x, -f.x, 0),
        SIMD4<Float>(s.y, u.y, -f.y, 0),
        SIMD4<Float>(s.z, u.z, -f.z, 0),
        SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
    ))
}

final class Renderer: NSObject, MTKViewDelegate {
    private let gl: GLContext
    private var instProgram: GLuint = 0
    private var compProgram: GLuint = 0
    private var transProgram: GLuint = 0
    private var cubeVAO: GLuint = 0
    private var transVAO: GLuint = 0
    private var quadVAO: GLuint = 0
    private var cubeVBO: GLuint = 0
    private var cubeIBO: GLuint = 0
    private var instVBO: GLuint = 0
    private var textures: [GLuint] = []
    private var gbAlbedo: GLuint = 0
    private var gbNormal: GLuint = 0
    private var resolveAlbedo: GLuint = 0
    private var resolveNormal: GLuint = 0
    private var fbo: GLuint = 0
    private var uViewProj = -1
    private var uTransMVP = -1
    private var uTransColor = -1
    private var instanceCount = 0
    private let start = CACurrentMediaTime()
    private var logged = false
    private var transparent: [(SIMD3<Float>, Float, SIMD4<Float>)] = []
    private var occlusionQuery: GLuint = 0
    private var computeProgram: GLuint = 0
    private var particleProgram: GLuint = 0
    private var particleVAO: GLuint = 0
    private var particleBuf: GLuint = 0
    private var paramsBuf: GLuint = 0
    private let particleCount = 4000
    private var uParticleViewProj = -1
    private var loggedParticles = false
    private var lastStats: Float = 0

    init(view: MTKView) {
        gl = GLContext(device: view.device!, view: view)
        super.init()
        setup()
    }

    private func makeComputeProgram(_ cs: String) -> GLuint {
        let c = gl.glCreateShader(GL_COMPUTE_SHADER)
        gl.glShaderSource(c, cs); gl.glCompileShader(c)
        let p = gl.glCreateProgram()
        gl.glAttachShader(p, c); gl.glLinkProgram(p)
        return p
    }

    private func makeProgram(_ vs: String, _ fs: String) -> GLuint {
        let v = gl.glCreateShader(GL_VERTEX_SHADER)
        gl.glShaderSource(v, vs); gl.glCompileShader(v)
        let f = gl.glCreateShader(GL_FRAGMENT_SHADER)
        gl.glShaderSource(f, fs); gl.glCompileShader(f)
        let p = gl.glCreateProgram()
        gl.glAttachShader(p, v); gl.glAttachShader(p, f); gl.glLinkProgram(p)
        return p
    }

    private func setup() {
        instProgram = makeProgram(ShaderSources.instVS, ShaderSources.instFS)
        compProgram = makeProgram(ShaderSources.compVS, ShaderSources.compFS)
        transProgram = makeProgram(ShaderSources.transVS, ShaderSources.transFS)
        gl.glUseProgram(instProgram)
        uViewProj = gl.glGetUniformLocation(instProgram, "uViewProj")
        gl.glUseProgram(transProgram)
        uTransMVP = gl.glGetUniformLocation(transProgram, "uMVP")
        uTransColor = gl.glGetUniformLocation(transProgram, "uColor")

        computeProgram = makeComputeProgram(ShaderSources.particleComp)
        particleProgram = makeProgram(ShaderSources.particleVS, ShaderSources.particleFS)
        gl.glUseProgram(particleProgram)
        uParticleViewProj = gl.glGetUniformLocation(particleProgram, "uViewProj")
        occlusionQuery = gl.glGenQueries()
        buildCubeAndInstances()
        buildParticles()
        buildTransVAO()
        buildQuad()
        loadTextures()

        transparent = [
            (SIMD3(0, 8, 0), 3.2, SIMD4(0.30, 0.75, 1.00, 0.35)),
            (SIMD3(-9, 6, 7), 2.4, SIMD4(1.00, 0.45, 0.80, 0.30)),
            (SIMD3(9, 5, -6), 2.8, SIMD4(0.45, 1.00, 0.55, 0.28)),
            (SIMD3(0, 4, -12), 2.0, SIMD4(1.00, 0.80, 0.30, 0.25))
        ]
    }

    private func buildCubeAndInstances() {
        let normals: [SIMD3<Float>] = [
            SIMD3(0, 0, 1), SIMD3(0, 0, -1), SIMD3(1, 0, 0),
            SIMD3(-1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, -1, 0)
        ]
        let corners: [[SIMD3<Float>]] = [
            [SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1)],
            [SIMD3(1, -1, -1), SIMD3(-1, -1, -1), SIMD3(-1, 1, -1), SIMD3(1, 1, -1)],
            [SIMD3(1, -1, 1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(1, 1, 1)],
            [SIMD3(-1, -1, -1), SIMD3(-1, -1, 1), SIMD3(-1, 1, 1), SIMD3(-1, 1, -1)],
            [SIMD3(-1, 1, 1), SIMD3(1, 1, 1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1)],
            [SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, -1, 1), SIMD3(-1, -1, 1)]
        ]
        let uvs: [SIMD2<Float>] = [SIMD2(0, 1), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 0)]
        var verts: [Float] = []
        var idx: [UInt32] = []
        for f in 0..<6 {
            let base = UInt32(verts.count / 8)
            for c in 0..<4 {
                let p = corners[f][c], n = normals[f], uv = uvs[c]
                verts += [p.x, p.y, p.z, n.x, n.y, n.z, uv.x, uv.y]
            }
            idx += [base, base + 1, base + 2, base, base + 2, base + 3]
        }

        cubeVAO = gl.glGenVertexArrays()
        gl.glBindVertexArray(cubeVAO)
        cubeVBO = gl.glGenBuffers()
        gl.glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
        verts.withUnsafeBytes { gl.glBufferData(GL_ARRAY_BUFFER, $0.baseAddress!, $0.count, GL_STATIC_DRAW) }
        gl.glEnableVertexAttribArray(0)
        gl.glVertexAttribPointer(0, 3, GL_FLOAT, false, 32, 0)
        gl.glEnableVertexAttribArray(1)
        gl.glVertexAttribPointer(1, 3, GL_FLOAT, false, 32, 12)
        gl.glEnableVertexAttribArray(2)
        gl.glVertexAttribPointer(2, 2, GL_FLOAT, false, 32, 24)
        cubeIBO = gl.glGenBuffers()
        gl.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cubeIBO)
        idx.withUnsafeBytes { gl.glBufferData(GL_ELEMENT_ARRAY_BUFFER, $0.baseAddress!, $0.count, GL_STATIC_DRAW) }

        var inst: [Float] = []
        let n = 28
        for x in 0..<n {
            for z in 0..<n {
                let fx = Float(x) - Float(n / 2)
                let fz = Float(z) - Float(n / 2)
                let h = 1.6 + (sin(fx * 0.35) + cos(fz * 0.35)) * 1.1
                let t = 0.55 + 0.45 * (h / 4.0)
                inst += [fx, h, fz, 0.46,
                         t, 0.65 + 0.35 * sin(fx * 0.2), 0.75 + 0.25 * cos(fz * 0.2)]
            }
        }
        instanceCount = inst.count / 7

        instVBO = gl.glGenBuffers()
        gl.glBindBuffer(GL_ARRAY_BUFFER, instVBO)
        inst.withUnsafeBytes { gl.glBufferData(GL_ARRAY_BUFFER, $0.baseAddress!, $0.count, GL_STATIC_DRAW) }
        gl.glEnableVertexAttribArray(3)
        gl.glVertexAttribPointer(3, 3, GL_FLOAT, false, 28, 0)
        gl.glVertexAttribDivisor(3, 1)
        gl.glEnableVertexAttribArray(4)
        gl.glVertexAttribPointer(4, 1, GL_FLOAT, false, 28, 12)
        gl.glVertexAttribDivisor(4, 1)
        gl.glEnableVertexAttribArray(5)
        gl.glVertexAttribPointer(5, 3, GL_FLOAT, false, 28, 16)
        gl.glVertexAttribDivisor(5, 1)

        HUD.shared.log("GL: " + gl.glGetString(GL_VERSION))
        gl.glBindBuffer(GL_ARRAY_BUFFER, instVBO)
        var firstInst = [Float](repeating: 0, count: 7)
        firstInst.withUnsafeMutableBytes { gl.glGetBufferSubData(GL_ARRAY_BUFFER, 0, 28, $0.baseAddress!) }
        HUD.shared.log("readback: instance[0] pos=(" + String(firstInst[0]) + "," + String(firstInst[1]) + "," + String(firstInst[2]) + ") scale=" + String(firstInst[3]))
        if let mapped = gl.glMapBufferRange(GL_ARRAY_BUFFER, 0, 28, 1) {
            let f = mapped.assumingMemoryBound(to: Float.self)
            HUD.shared.log("mapped: instance[0].x=" + String(f[0]))
            _ = gl.glUnmapBuffer(GL_ARRAY_BUFFER)
        }
        HUD.shared.log("instances: \(instanceCount)")
    }

    private func buildParticles() {
        var data = [Float](repeating: 0, count: particleCount * 8)
        for i in 0..<particleCount {
            let a = Float(i) * 2.3999632
            let r = Float(i) / Float(particleCount)
            let x = cos(a) * r * 12.0
            let z = sin(a) * r * 12.0
            let y = 5.0 + r * 10.0
            let o = i * 8
            data[o + 0] = x; data[o + 1] = y; data[o + 2] = z; data[o + 3] = 1
            data[o + 4] = cos(a) * 1.5; data[o + 5] = 2.0; data[o + 6] = sin(a) * 1.5; data[o + 7] = 0
        }
        particleBuf = gl.glGenBuffers()
        gl.glBindBuffer(GL_ARRAY_BUFFER, particleBuf)
        data.withUnsafeBytes { gl.glBufferData(GL_ARRAY_BUFFER, $0.baseAddress!, $0.count, GL_STATIC_DRAW) }
        paramsBuf = gl.glGenBuffers()

        particleVAO = gl.glGenVertexArrays()
        gl.glBindVertexArray(particleVAO)
        gl.glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
        gl.glEnableVertexAttribArray(0)
        gl.glVertexAttribPointer(0, 3, GL_FLOAT, false, 32, 0)
        gl.glEnableVertexAttribArray(2)
        gl.glVertexAttribPointer(2, 2, GL_FLOAT, false, 32, 24)
        gl.glBindBuffer(GL_ARRAY_BUFFER, particleBuf)
        gl.glEnableVertexAttribArray(3)
        gl.glVertexAttribPointer(3, 3, GL_FLOAT, false, 32, 0)
        gl.glVertexAttribDivisor(3, 1)
        gl.glEnableVertexAttribArray(4)
        gl.glVertexAttribPointer(4, 3, GL_FLOAT, false, 32, 16)
        gl.glVertexAttribDivisor(4, 1)
        gl.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cubeIBO)
        HUD.shared.log("particles: " + String(particleCount) + " (TF emulated via compute)")
    }

    private func buildTransVAO() {
        transVAO = gl.glGenVertexArrays()
        gl.glBindVertexArray(transVAO)
        gl.glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
        gl.glEnableVertexAttribArray(0)
        gl.glVertexAttribPointer(0, 3, GL_FLOAT, false, 32, 0)
        gl.glEnableVertexAttribArray(2)
        gl.glVertexAttribPointer(2, 2, GL_FLOAT, false, 32, 24)
        gl.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, cubeIBO)
    }

    private func buildQuad() {
        let q: [Float] = [-1, -1, 1, -1, 1, 1, -1, -1, 1, 1, -1, 1]
        quadVAO = gl.glGenVertexArrays()
        gl.glBindVertexArray(quadVAO)
        let vbo = gl.glGenBuffers()
        gl.glBindBuffer(GL_ARRAY_BUFFER, vbo)
        q.withUnsafeBytes { gl.glBufferData(GL_ARRAY_BUFFER, $0.baseAddress!, $0.count, GL_STATIC_DRAW) }
        gl.glEnableVertexAttribArray(0)
        gl.glVertexAttribPointer(0, 2, GL_FLOAT, false, 8, 0)
    }

    private func loadTextures() {
        for i in 0..<4 {
            let id = gl.glGenTextures()
            gl.glActiveTexture(GL_TEXTURE0)
            gl.glBindTexture(GL_TEXTURE_2D, id)
            guard let url = Bundle.main.url(forResource: "tex\(i)", withExtension: "png"),
                  let img = UIImage(contentsOfFile: url.path),
                  let cg = img.cgImage else {
                HUD.shared.log("tex\(i) missing")
                textures.append(id)
                continue
            }
            let w = cg.width, h = cg.height
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            let cs = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w * 4, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
            gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
            gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            bytes.withUnsafeBytes { gl.glTexImage2D(GL_TEXTURE_2D, 0, 0, w, h, 0, 0, 0, $0.baseAddress) }
            textures.append(id)
        }
        HUD.shared.log("textures: \(textures.count)")
    }

    private func setupFBO(_ w: Int, _ h: Int) {
        gl.glActiveTexture(GL_TEXTURE0)
        gbAlbedo = gl.glGenTextures()
        gl.glBindTexture(GL_TEXTURE_2D, gbAlbedo)
        gl.glTexImage2DMultisample(GL_TEXTURE_2D, 4, 0, w, h, true)
        gbNormal = gl.glGenTextures()
        gl.glBindTexture(GL_TEXTURE_2D, gbNormal)
        gl.glTexImage2DMultisample(GL_TEXTURE_2D, 4, 0, w, h, true)
        resolveAlbedo = gl.glGetResolvedTexture(gbAlbedo)
        resolveNormal = gl.glGetResolvedTexture(gbNormal)

        fbo = gl.glGenFramebuffers()
        gl.glBindFramebuffer(GL_FRAMEBUFFER, fbo)
        gl.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, gbAlbedo, 0)
        gl.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + 1, GL_TEXTURE_2D, gbNormal, 0)
        gl.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, 0, 0)
        gl.glBindFramebuffer(GL_FRAMEBUFFER, 0)
        HUD.shared.log("gbuffer: 4x MSAA, 2 MRT + depth \(w)x\(h)")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let t = Float(CACurrentMediaTime() - start)
        let w = Int(view.drawableSize.width), h = Int(view.drawableSize.height)
        if fbo == 0 { setupFBO(w, h) }
        let aspect = Float(max(w, 1)) / Float(max(h, 1))
        let proj = perspective(55 * Float.pi / 180, aspect)
        let a = t * 0.12
        let eye = SIMD3<Float>(56 * sin(a), 30, 56 * cos(a))
        let viewM = lookAt(eye, SIMD3<Float>(0, 2.0, 0), SIMD3<Float>(0, 1, 0))
        let vp = proj * viewM

        // --- compute pass: the transform-feedback replacement ---
        var dt: Float = 1.0 / 60.0
        gl.glBindBuffer(GL_ARRAY_BUFFER, paramsBuf)
        withUnsafeBytes(of: &dt) { gl.glBufferData(GL_ARRAY_BUFFER, $0.baseAddress!, 4, GL_STATIC_DRAW) }
        gl.glUseProgram(computeProgram)
        gl.glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, particleBuf)
        gl.glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, paramsBuf)
        gl.glDispatchCompute((particleCount + 63) / 64, 1, 1)

        // --- GBuffer: one instanced draw, wrapped in an occlusion query ---
        gl.glBeginQuery(GL_SAMPLES_PASSED, occlusionQuery)
        gl.glBindFramebuffer(GL_FRAMEBUFFER, fbo)
        gl.glEnable(GL_DEPTH_TEST)
        gl.glDepthFunc(GL_LESS)
        gl.glEnable(GL_CULL_FACE)
        gl.glFrontFace(GL_CCW)
        gl.glClearColor(0, 0, 0, 1)
        gl.glClearDepth(1.0)
        gl.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        gl.glUseProgram(instProgram)
        gl.glBindVertexArray(cubeVAO)
        var vpm = vp
        gl.glUniformMatrix4fv(uViewProj, 1, false, &vpm)
        gl.glActiveTexture(GL_TEXTURE0)
        gl.glBindTexture(GL_TEXTURE_2D, textures[0])
        gl.glDrawElementsInstanced(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0, instanceCount)
        gl.glEndQuery(GL_SAMPLES_PASSED)

        // --- composite ---
        gl.glBindFramebuffer(GL_FRAMEBUFFER, 0)
        gl.glDisable(GL_DEPTH_TEST)
        gl.glDisable(GL_CULL_FACE)
        gl.glClearColor(0.03, 0.04, 0.07, 1)
        gl.glClear(GL_COLOR_BUFFER_BIT)
        gl.glDepthMask(false)
        gl.glUseProgram(compProgram)
        gl.glActiveTexture(GL_TEXTURE0)
        gl.glBindTexture(GL_TEXTURE_2D, resolveAlbedo)
        gl.glActiveTexture(GL_TEXTURE0 + 1)
        gl.glBindTexture(GL_TEXTURE_2D, resolveNormal)
        gl.glBindVertexArray(quadVAO)
        gl.glDrawArrays(GL_TRIANGLES, 0, 6)

        // picture-in-picture: same quad, scissored + viewported
        let iw = w / 3, ih = h / 6
        let ix = w - iw - 24, iy = 40
        gl.glEnable(GL_SCISSOR_TEST)
        gl.glViewport(ix, iy, iw, ih)
        gl.glScissor(ix, iy, iw, ih)
        gl.glDrawArrays(GL_TRIANGLES, 0, 6)
        gl.glDisable(GL_SCISSOR_TEST)
        gl.glViewport(0, 0, w, h)

        // --- particles: forward, additive, depth writes off ---
        gl.glEnable(GL_BLEND)
        gl.glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        gl.glDepthMask(false)
        gl.glDisable(GL_DEPTH_TEST)
        gl.glUseProgram(particleProgram)
        var vpp = vp
        gl.glUniformMatrix4fv(uParticleViewProj, 1, false, &vpp)
        gl.glBindVertexArray(particleVAO)
        gl.glDrawElementsInstanced(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0, particleCount)
        if !loggedParticles {
            loggedParticles = true
            var p0 = [Float](repeating: 0, count: 8)
            gl.glBindBuffer(GL_ARRAY_BUFFER, particleBuf)
            p0.withUnsafeMutableBytes { gl.glGetBufferSubData(GL_ARRAY_BUFFER, 0, 32, $0.baseAddress!) }
            HUD.shared.log("particle0 y=" + String(p0[1]) + " draws=" + String(gl.drawCalls) + " vp=" + String(uParticleViewProj))
        }

        // --- forward transparent pass ---
        gl.glEnable(GL_BLEND)
        gl.glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        gl.glDepthMask(false)
        gl.glDisable(GL_DEPTH_TEST)
        gl.glUseProgram(transProgram)
        gl.glBindVertexArray(transVAO)
        gl.glActiveTexture(GL_TEXTURE0)
        gl.glBindTexture(GL_TEXTURE_2D, textures[0])
        let sorted = transparent.sorted {
            simd_length_squared($0.0 - eye) > simd_length_squared($1.0 - eye)
        }
        for (pos, size, color) in sorted {
            var m = proj * viewM * translation(pos.x, pos.y, pos.z) * scaleMatrix(size)
            gl.glUniformMatrix4fv(uTransMVP, 1, false, &m)
            gl.glUniform4f(uTransColor, color.x, color.y, color.z, color.w)
            gl.glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0)
        }
        gl.glDepthMask(true)
        gl.glDisable(GL_BLEND)

        let fence = gl.glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
        gl.glEndFrame()
        let w0 = CACurrentMediaTime()
        _ = gl.glClientWaitSync(fence, 0, 8_000_000)
        let waitMs = (CACurrentMediaTime() - w0) * 1000.0
        gl.glDeleteSync(fence)

        if t - lastStats > 2.0 {
            lastStats = t
            let avail = gl.glGetQueryObjectuiv(occlusionQuery, GL_QUERY_RESULT_AVAILABLE)
            let samples = gl.glGetQueryObjectuiv(occlusionQuery, GL_QUERY_RESULT)
            HUD.shared.log("occlusion: " + String(samples) + " samples (ready=" + String(avail) + ")")
            HUD.shared.log("fence wait: " + String(format: "%.2f", waitMs) + " ms")
            var px = [UInt8](repeating: 0, count: 4)
            px.withUnsafeMutableBytes { gl.glReadPixelsFromTexture(resolveAlbedo, w / 2, h / 2, 1, 1, $0.baseAddress!) }
            HUD.shared.log("gbuffer pixel: " + String(px[0]) + "," + String(px[1]) + "," + String(px[2]))
        }

        if !logged, t > 2 {
            logged = true
            HUD.shared.log("draws: 2 + \(transparent.count) transparent")
        }
    }
}

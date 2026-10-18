import Metal
import MetalKit
import simd

typealias GLuint = UInt32

let GL_VERTEX_SHADER: UInt32 = 0x8B31
let GL_FRAGMENT_SHADER: UInt32 = 0x8B30
let GL_ARRAY_BUFFER: UInt32 = 0x8892
let GL_ELEMENT_ARRAY_BUFFER: UInt32 = 0x8893
let GL_STATIC_DRAW: UInt32 = 0x88E4
let GL_TRIANGLES: UInt32 = 0x0004
let GL_FLOAT: UInt32 = 0x1406
let GL_UNSIGNED_INT: UInt32 = 0x1405
let GL_TEXTURE_2D: UInt32 = 0x0DE1
let GL_TEXTURE0: UInt32 = 0x84C0
let GL_COLOR_BUFFER_BIT: UInt32 = 0x4000
let GL_DEPTH_BUFFER_BIT: UInt32 = 0x0100
let GL_DEPTH_TEST: UInt32 = 0x0B71
let GL_CULL_FACE: UInt32 = 0x0B44
let GL_BLEND: UInt32 = 0x0BE2
let GL_LESS: UInt32 = 0x0201
let GL_LEQUAL: UInt32 = 0x0203
let GL_ALWAYS: UInt32 = 0x0207
let GL_BACK: UInt32 = 0x0405
let GL_FRONT: UInt32 = 0x0404
let GL_CCW: UInt32 = 0x0901
let GL_CW: UInt32 = 0x0900
let GL_SRC_ALPHA: UInt32 = 0x0302
let GL_ONE_MINUS_SRC_ALPHA: UInt32 = 0x0303
let GL_DST_COLOR: UInt32 = 0x0306
let GL_ONE_MINUS_DST_COLOR: UInt32 = 0x0307
let GL_ONE: UInt32 = 1
let GL_ZERO: UInt32 = 0
let GL_TEXTURE_MIN_FILTER: UInt32 = 0x2801
let GL_TEXTURE_MAG_FILTER: UInt32 = 0x2800
let GL_NEAREST: UInt32 = 0x2600
let GL_LINEAR: UInt32 = 0x2601
let GL_TEXTURE_WRAP_S: UInt32 = 0x2802
let GL_TEXTURE_WRAP_T: UInt32 = 0x2803
let GL_CLAMP_TO_EDGE: UInt32 = 0x812F
let GL_REPEAT: UInt32 = 0x2901
let GL_FRAMEBUFFER: UInt32 = 0x8D40
let GL_COLOR_ATTACHMENT0: UInt32 = 0x8CE0
let GL_DEPTH_ATTACHMENT: UInt32 = 0x8D00
let GL_FRAMEBUFFER_COMPLETE: UInt32 = 0x8CD5
let GL_VERSION: UInt32 = 0x1F02
let GL_SCISSOR_TEST: UInt32 = 0x0B90
let GL_COMPUTE_SHADER: UInt32 = 0x91B9
let GL_SHADER_STORAGE_BUFFER: UInt32 = 0x90D2
let GL_SAMPLES_PASSED: UInt32 = 0x8914
let GL_ANY_SAMPLES_PASSED: UInt32 = 0x8C2F
let GL_QUERY_RESULT: UInt32 = 0x8866
let GL_QUERY_RESULT_AVAILABLE: UInt32 = 0x8867
let GL_SYNC_GPU_COMMANDS_COMPLETE: UInt32 = 0x9117
let GL_ALREADY_SIGNALED: UInt32 = 0x911A
let GL_TIMEOUT_EXPIRED: UInt32 = 0x911B
let GL_CONDITION_SATISFIED: UInt32 = 0x911C
let GL_WAIT_FAILED: UInt32 = 0x911D

enum ShaderTranslator {
    static func translate(_ glsl: String) -> String {
        if glsl == ShaderSources.basicVS { return ShaderSources.basicVSMSL }
        if glsl == ShaderSources.basicFS { return ShaderSources.basicFSMSL }
        if glsl == ShaderSources.gbVS { return ShaderSources.gbVSMSL }
        if glsl == ShaderSources.gbFS { return ShaderSources.gbFSMSL }
        if glsl == ShaderSources.compVS { return ShaderSources.compVSMSL }
        if glsl == ShaderSources.compFS { return ShaderSources.compFSMSL }
        if glsl == ShaderSources.instVS { return ShaderSources.instVSMSL }
        if glsl == ShaderSources.instFS { return ShaderSources.instFSMSL }
        if glsl == ShaderSources.transVS { return ShaderSources.transVSMSL }
        if glsl == ShaderSources.transFS { return ShaderSources.transFSMSL }
        if glsl == ShaderSources.particleVS { return ShaderSources.particleVSMSL }
        if glsl == ShaderSources.particleFS { return ShaderSources.particleFSMSL }
        if glsl == ShaderSources.particleComp { return ShaderSources.particleCompMSL }
        return ShaderSources.basicVSMSL
    }

    static func reflect(_ msl: String) -> [String: (index: Int, size: Int)] {
        var out: [String: (Int, Int)] = [:]
        let pattern = "constant\\s+(float4x4|float4|float3|float2|float|int)\\s*&?\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*\\[\\[buffer\\((\\d+)\\)\\]\\]"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return out }
        let ns = msl as NSString
        for m in re.matches(in: msl, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges == 4 else { continue }
            let type = ns.substring(with: m.range(at: 1))
            let name = ns.substring(with: m.range(at: 2))
            let idx = Int(ns.substring(with: m.range(at: 3))) ?? 0
            let size: Int
            switch type {
            case "float4x4": size = 64
            case "float4": size = 16
            case "float3": size = 12
            case "float2": size = 8
            default: size = 4
            }
            out[name] = (idx, size)
        }
        return out
    }
}

struct RenderTarget {
    var colors: [MTLPixelFormat]
    var depth: MTLPixelFormat?
    var samples: Int = 1
    var key: String {
        colors.map { String($0.rawValue) }.joined(separator: ",") + "|" + (depth.map { String($0.rawValue) } ?? "-") + "|s\(samples)"
    }
}

final class GLVAO {
    var attribs: [Int: (size: Int, stride: Int, offset: Int, buffer: GLuint, divisor: Int)] = [:]
    var elementBuffer: GLuint = 0
}

final class GLProgram {
    var vertexLib: MTLLibrary?
    var fragmentLib: MTLLibrary?
    var vertexUniforms: [String: (index: Int, size: Int)] = [:]
    var fragmentUniforms: [String: (index: Int, size: Int)] = [:]
    var locations: [String: Int] = [:]
    var locationNames: [Int: String] = [:]
    var nextLocation = 0
    var computeLib: MTLLibrary?
    var computePipeline: MTLComputePipelineState?
    var pipeline: MTLRenderPipelineState?
    var pipelineKey = ""
}

final class GLTexture {
    let texture: MTLTexture
    var sampleCount: Int = 1
    var resolve: MTLTexture?
    var resolveID: GLuint = 0
    var minFilter: UInt32 = GL_LINEAR
    var magFilter: UInt32 = GL_LINEAR
    var wrapS: UInt32 = GL_REPEAT
    var wrapT: UInt32 = GL_REPEAT
    var sampler: MTLSamplerState?
    init(_ t: MTLTexture) { texture = t }
}

final class GLQuery {
    let buffer: MTLBuffer
    var active = false
    var ready = false
    var value: UInt32 = 0
    let lock = NSLock()
    init(buffer: MTLBuffer) { self.buffer = buffer }
}

final class GLFence {
    var signaled = false
    let sem = DispatchSemaphore(value: 0)
    let lock = NSLock()
    init(cb: MTLCommandBuffer?) {
        guard let cb = cb else { signaled = true; return }
        cb.addCompletedHandler { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock(); self.signaled = true; self.lock.unlock()
            self.sem.signal()
        }
    }
}

final class GLFBO {
    var colors: [GLuint] = []
    var depthTexture: MTLTexture?
}

final class GLContext {
    let device: MTLDevice
    let queue: MTLCommandQueue
    weak var view: MTKView?

    /// Bind (or clear) the drawable backing the default framebuffer.
    /// The C ABI entry point HytaleGL_AttachView forwards here.
    func attachView(_ v: MTKView?) { view = v }

    private var nextID: GLuint = 1
    private var shaders: [GLuint: (stage: UInt32, glsl: String)] = [:]
    private var programs: [GLuint: GLProgram] = [:]
    private var attached: [GLuint: [GLuint]] = [:]
    private var buffers: [GLuint: MTLBuffer] = [:]
    private var vaos: [GLuint: GLVAO] = [:]
    private var textures: [GLuint: GLTexture] = [:]
    private var framebuffers: [GLuint: GLFBO] = [:]
    private var queries: [GLuint: GLQuery] = [:]
    private var fences: [GLuint: GLFence] = [:]
    private var activeQuery: GLuint = 0
    private var ssbo: [Int: GLuint] = [:]
    private var vertexBytes: [GLuint: [Int: [UInt8]]] = [:]
    private var fragmentBytes: [GLuint: [Int: [UInt8]]] = [:]

    private var currentProgram: GLuint = 0
    private var currentVAO: GLuint = 0
    private var currentFBO: GLuint = 0
    private var boundArrayBuffer: GLuint = 0
    private var boundElementBuffer: GLuint = 0
    private var activeUnit = 0
    private var boundTextures: [Int: GLuint] = [:]

    private var depthTest = false
    private var depthWrite = true
    private var depthFunc: UInt32 = GL_LESS
    private var cullFace = false
    private var frontFace: UInt32 = GL_CCW
    private var cullFaceMode: UInt32 = GL_BACK
    private var blend = false
    private var blendSrc: UInt32 = GL_SRC_ALPHA
    private var blendDst: UInt32 = GL_ONE_MINUS_SRC_ALPHA
    private var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    private var clearDepth: Double = 1.0

    private var encoder: MTLRenderCommandEncoder?
    private var cmd: MTLCommandBuffer?
    private var currentTarget = RenderTarget(colors: [], depth: nil)
    private var lastPassDefault = false
    private var vpRect: (Int, Int, Int, Int)? = nil
    private var scissorOn = false
    private var scissorRect: (Int, Int, Int, Int) = (0, 0, 0, 0)
    private var targetHeight = 0
    private var targetWidth = 0
    private var loggedFBO = false
    private var loggedSkip = false
    private var loggedUB = false
    private var depthStates: [String: MTLDepthStencilState] = [:]
    private(set) var drawCalls = 0

    init(device: MTLDevice, view: MTKView?) {
        self.device = device
        self.queue = device.makeCommandQueue()!
        self.view = view
    }

    func glCreateShader(_ type: UInt32) -> GLuint { let id = nextID; nextID += 1; shaders[id] = (type, ""); return id }
    func glShaderSource(_ id: GLuint, _ src: String) { shaders[id]?.glsl = src }
    func glCompileShader(_ id: GLuint) {}
    func glCreateProgram() -> GLuint {
        let id = nextID; nextID += 1; programs[id] = GLProgram(); attached[id] = []; return id
    }
    func glAttachShader(_ p: GLuint, _ s: GLuint) { attached[p]?.append(s) }
    func glLinkProgram(_ p: GLuint) {
        guard let prog = programs[p] else { return }
        for sid in attached[p] ?? [] {
            guard let s = shaders[sid] else { continue }
            let msl = ShaderTranslator.translate(s.glsl)
            if s.stage == GL_COMPUTE_SHADER {
                do { prog.computeLib = try device.makeLibrary(source: msl, options: nil) }
                catch { HUD.shared.log("compute compile error: \(error)") }
                continue
            }
            let refl = ShaderTranslator.reflect(msl)
            if s.stage == GL_VERTEX_SHADER {
                for (k, v) in refl { prog.vertexUniforms[k] = v }
            } else {
                for (k, v) in refl { prog.fragmentUniforms[k] = v }
            }
            do {
                let lib = try device.makeLibrary(source: msl, options: nil)
                if s.stage == GL_VERTEX_SHADER { prog.vertexLib = lib } else { prog.fragmentLib = lib }
            } catch { HUD.shared.log("metal compile error: \(error)") }
        }
        let names = Set(prog.vertexUniforms.keys).union(prog.fragmentUniforms.keys).sorted()
        for name in names {
            prog.locations[name] = prog.nextLocation
            prog.locationNames[prog.nextLocation] = name
            prog.nextLocation += 1
        }
        HUD.shared.log("uniforms: v=\(prog.vertexUniforms.count) f=\(prog.fragmentUniforms.count)")
    }
    func glUseProgram(_ p: GLuint) { currentProgram = p }

    func glGenBuffers() -> GLuint { let id = nextID; nextID += 1; return id }
    func glBindBuffer(_ target: UInt32, _ id: GLuint) {
        if target == GL_ELEMENT_ARRAY_BUFFER { boundElementBuffer = id; vaos[currentVAO]?.elementBuffer = id }
        else { boundArrayBuffer = id }
    }
    func glBufferData(_ target: UInt32, _ ptr: UnsafeRawPointer, _ size: Int, _ usage: UInt32) {
        let id = (target == GL_ELEMENT_ARRAY_BUFFER) ? boundElementBuffer : boundArrayBuffer
        buffers[id] = device.makeBuffer(bytes: ptr, length: size, options: .storageModeShared)
    }

    func glGenVertexArrays() -> GLuint { let id = nextID; nextID += 1; vaos[id] = GLVAO(); return id }
    func glBindVertexArray(_ id: GLuint) { currentVAO = id }
    func glEnableVertexAttribArray(_ index: Int) {}
    func glVertexAttribDivisor(_ index: Int, _ divisor: Int) {
        guard var a = vaos[currentVAO]?.attribs[index] else { return }
        a.divisor = divisor
        vaos[currentVAO]?.attribs[index] = a
    }
    func glVertexAttribPointer(_ index: Int, _ size: Int, _ type: UInt32, _ normalized: Bool, _ stride: Int, _ offset: Int) {
        vaos[currentVAO]?.attribs[index] = (size, stride, offset, boundArrayBuffer, 0)
    }

    func glGetUniformLocation(_ program: GLuint, _ name: String) -> Int {
        return programs[program]?.locations[name] ?? -1
    }
    private func setUniform(_ loc: Int, _ bytes: [UInt8]) {
        guard loc >= 0, let prog = programs[currentProgram], let name = prog.locationNames[loc] else { return }
        if let v = prog.vertexUniforms[name] { vertexBytes[currentProgram, default: [:]][v.index] = bytes }
        if let f = prog.fragmentUniforms[name] { fragmentBytes[currentProgram, default: [:]][f.index] = bytes }
    }
    func glUniformMatrix4fv(_ loc: Int, _ count: Int, _ transpose: Bool, _ value: UnsafePointer<simd_float4x4>) {
        var m = value.pointee
        setUniform(loc, withUnsafeBytes(of: &m) { Array($0) })
    }
    func glUniform1f(_ loc: Int, _ v: Float) { setUniform(loc, withUnsafeBytes(of: v) { Array($0) }) }
    func glUniform1i(_ loc: Int, _ v: Int32) { setUniform(loc, withUnsafeBytes(of: v) { Array($0) }) }
    func glUniform4f(_ loc: Int, _ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        var v = SIMD4<Float>(x, y, z, w)
        setUniform(loc, withUnsafeBytes(of: &v) { Array($0) })
    }

    func glGenTextures() -> GLuint { let id = nextID; nextID += 1; return id }
    func glActiveTexture(_ unit: UInt32) { activeUnit = Int(unit - GL_TEXTURE0) }
    func glBindTexture(_ target: UInt32, _ id: GLuint) { boundTextures[activeUnit] = id }

    func glTexImage2D(_ target: UInt32, _ level: Int, _ internalFormat: Int,
                      _ width: Int, _ height: Int, _ border: Int,
                      _ format: UInt32, _ type: UInt32, _ pixels: UnsafeRawPointer?) {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                         width: width, height: height, mipmapped: false)
        d.usage = [.shaderRead, .renderTarget]
        guard let tex = device.makeTexture(descriptor: d) else { return }
        if let p = pixels {
            tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: p, bytesPerRow: width * 4)
        }
        textures[boundTextures[activeUnit] ?? 0] = GLTexture(tex)
    }

    func glTexImage2DMultisample(_ target: UInt32, _ samples: Int, _ internalFormat: Int,
                                 _ width: Int, _ height: Int, _ fixedsamplelocations: Bool) {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                         width: width, height: height, mipmapped: false)
        d.textureType = .type2DMultisample
        d.sampleCount = samples
        d.usage = .renderTarget
        d.storageMode = .private
        guard let msaa = device.makeTexture(descriptor: d) else { return }
        let rd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                          width: width, height: height, mipmapped: false)
        rd.usage = [.shaderRead, .renderTarget]
        guard let resolve = device.makeTexture(descriptor: rd) else { return }
        let resolveID = nextID; nextID += 1
        textures[resolveID] = GLTexture(resolve)
        let gt = GLTexture(msaa)
        gt.sampleCount = samples
        gt.resolve = resolve
        gt.resolveID = resolveID
        textures[boundTextures[activeUnit] ?? 0] = gt
    }

    func glGetResolvedTexture(_ id: GLuint) -> GLuint {
        return textures[id]?.resolveID ?? id
    }

    func glTexParameteri(_ target: UInt32, _ pname: UInt32, _ param: UInt32) {
        guard let t = textures[boundTextures[activeUnit] ?? 0] else { return }
        switch pname {
        case GL_TEXTURE_MIN_FILTER: t.minFilter = param
        case GL_TEXTURE_MAG_FILTER: t.magFilter = param
        case GL_TEXTURE_WRAP_S: t.wrapS = param
        case GL_TEXTURE_WRAP_T: t.wrapT = param
        default: break
        }
        t.sampler = nil
    }

    private func sampler(for t: GLTexture) -> MTLSamplerState {
        if let s = t.sampler { return s }
        let sd = MTLSamplerDescriptor()
        sd.minFilter = t.minFilter == GL_NEAREST ? .nearest : .linear
        sd.magFilter = t.magFilter == GL_NEAREST ? .nearest : .linear
        sd.sAddressMode = t.wrapS == GL_REPEAT ? .repeat : .clampToEdge
        sd.tAddressMode = t.wrapT == GL_REPEAT ? .repeat : .clampToEdge
        let s = device.makeSamplerState(descriptor: sd)!
        t.sampler = s
        return s
    }

    func glGenFramebuffers() -> GLuint { let id = nextID; nextID += 1; framebuffers[id] = GLFBO(); return id }

    func glBindFramebuffer(_ target: UInt32, _ id: GLuint) {
        if currentFBO != id { endPass(); currentFBO = id }
    }

    func glFramebufferTexture2D(_ target: UInt32, _ attachment: UInt32, _ textarget: UInt32,
                                _ texture: GLuint, _ level: Int) {
        guard let fbo = framebuffers[currentFBO] else { return }
        if attachment == GL_DEPTH_ATTACHMENT {
            guard let first = fbo.colors.first, let gt = textures[first] else { return }
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                             width: gt.texture.width, height: gt.texture.height, mipmapped: false)
            d.usage = .renderTarget
            d.storageMode = .private
            if gt.sampleCount > 1 {
                d.textureType = .type2DMultisample
                d.sampleCount = gt.sampleCount
            }
            fbo.depthTexture = device.makeTexture(descriptor: d)
        } else {
            let idx = Int(attachment - GL_COLOR_ATTACHMENT0)
            while fbo.colors.count <= idx { fbo.colors.append(0) }
            fbo.colors[idx] = texture
        }
    }

    func glCheckFramebufferStatus(_ target: UInt32) -> UInt32 { return GL_FRAMEBUFFER_COMPLETE }

    // MARK: queries (occlusion via Metal visibility buffer)

    func glGenQueries() -> GLuint {
        let id = nextID; nextID += 1
        let buf = device.makeBuffer(length: 8, options: .storageModeShared)!
        queries[id] = GLQuery(buffer: buf)
        return id
    }

    func glDeleteQueries(_ id: GLuint) { queries[id] = nil }

    func glBeginQuery(_ target: UInt32, _ id: GLuint) {
        guard queries[id] != nil else { return }
        if encoder != nil { endPass() }
        queries[id]?.active = true
        activeQuery = id
    }

    func glEndQuery(_ target: UInt32) {
        guard activeQuery != 0, let q = queries[activeQuery] else { return }
        if let enc = encoder { enc.setVisibilityResultMode(.disabled, offset: 0) }
        q.active = false
        let cb = cmd
        if let cb = cb {
            cb.addCompletedHandler { _ in
                q.lock.lock()
                q.value = UInt32(truncatingIfNeeded: q.buffer.contents().load(as: UInt64.self))
                q.ready = true
                q.lock.unlock()
            }
        } else {
            q.lock.lock(); q.ready = true; q.lock.unlock()
        }
        activeQuery = 0
    }

    func glGetQueryObjectuiv(_ id: GLuint, _ pname: UInt32) -> UInt32 {
        guard let q = queries[id] else { return 0 }
        q.lock.lock(); defer { q.lock.unlock() }
        if pname == GL_QUERY_RESULT_AVAILABLE { return q.ready ? 1 : 0 }
        return q.value
    }

    // MARK: fences

    func glFenceSync(_ condition: UInt32, _ flags: UInt32) -> GLuint {
        let id = nextID; nextID += 1
        fences[id] = GLFence(cb: cmd)
        return id
    }

    func glClientWaitSync(_ id: GLuint, _ flags: UInt32, _ timeoutNanos: UInt64) -> UInt32 {
        guard let f = fences[id] else { return GL_WAIT_FAILED }
        f.lock.lock(); let done = f.signaled; f.lock.unlock()
        if done { return GL_ALREADY_SIGNALED }
        let deadline = DispatchTime.now() + .nanoseconds(Int(min(timeoutNanos, 2_000_000_000)))
        return f.sem.wait(timeout: deadline) == .success ? GL_CONDITION_SATISFIED : GL_TIMEOUT_EXPIRED
    }

    func glDeleteSync(_ id: GLuint) { fences[id] = nil }
    func glIsSync(_ id: GLuint) -> Bool { return fences[id] != nil }

    // MARK: buffer mapping / readback

    func glMapBufferRange(_ target: UInt32, _ offset: Int, _ length: Int, _ access: UInt32) -> UnsafeMutableRawPointer? {
        let id = (target == GL_ELEMENT_ARRAY_BUFFER) ? boundElementBuffer : boundArrayBuffer
        guard let buf = buffers[id] else { return nil }
        return buf.contents().advanced(by: offset)
    }

    func glUnmapBuffer(_ target: UInt32) -> Bool { return true }

    func glGetBufferSubData(_ target: UInt32, _ offset: Int, _ size: Int, _ dst: UnsafeMutableRawPointer) {
        let id = (target == GL_ELEMENT_ARRAY_BUFFER) ? boundElementBuffer : boundArrayBuffer
        guard let buf = buffers[id] else { return }
        memcpy(dst, buf.contents().advanced(by: offset), size)
    }

    func glReadPixelsFromTexture(_ id: GLuint, _ x: Int, _ y: Int, _ w: Int, _ h: Int,
                                 _ pixels: UnsafeMutableRawPointer) {
        guard let t = textures[id]?.texture else { return }
        t.getBytes(pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(x, y, w, h), mipmapLevel: 0)
    }

    func glReadPixels(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ format: UInt32, _ type: UInt32, _ pixels: UnsafeMutableRawPointer) {
        guard currentFBO != 0, let fbo = framebuffers[currentFBO], let first = fbo.colors.first,
              let tex = textures[first]?.texture else { return }
        tex.getBytes(pixels, bytesPerRow: w * 4,
                     from: MTLRegionMake2D(x, y, w, h), mipmapLevel: 0)
    }

    func glEnable(_ cap: UInt32) {
        if cap == GL_DEPTH_TEST { depthTest = true }
        if cap == GL_CULL_FACE { cullFace = true }
        if cap == GL_BLEND { blend = true }
        if cap == GL_SCISSOR_TEST { scissorOn = true }
    }
    func glDisable(_ cap: UInt32) {
        if cap == GL_DEPTH_TEST { depthTest = false }
        if cap == GL_CULL_FACE { cullFace = false }
        if cap == GL_BLEND { blend = false }
        if cap == GL_SCISSOR_TEST { scissorOn = false }
    }
    func glDepthFunc(_ f: UInt32) { depthFunc = f }
    func glDepthMask(_ flag: Bool) { depthWrite = flag }
    func glCullFace(_ mode: UInt32) { cullFaceMode = mode }
    func glFrontFace(_ mode: UInt32) { frontFace = mode }
    func glBlendFunc(_ s: UInt32, _ d: UInt32) { blendSrc = s; blendDst = d }
    func glClearColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        clearColor = MTLClearColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }
    func glClearDepth(_ d: Double) { clearDepth = d }
    func glViewport(_ x: Int, _ y: Int, _ w: Int, _ h: Int) { vpRect = (x, y, w, h) }
    func glScissor(_ x: Int, _ y: Int, _ w: Int, _ h: Int) { scissorRect = (x, y, w, h) }
    func glClear(_ mask: UInt32) { beginEncoder() }
    func glBindBufferBase(_ target: UInt32, _ index: Int, _ buffer: GLuint) {
        if target == GL_SHADER_STORAGE_BUFFER { ssbo[index] = buffer }
    }

    func glDispatchCompute(_ x: Int, _ y: Int, _ z: Int) {
        guard let prog = programs[currentProgram], let lib = prog.computeLib,
              let fn = lib.makeFunction(name: "main0") else { return }
        if prog.computePipeline == nil {
            prog.computePipeline = try? device.makeComputePipelineState(function: fn)
        }
        guard let ps = prog.computePipeline, let cb = queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(ps)
        for (idx, bufId) in ssbo {
            if let mtl = buffers[bufId] { enc.setBuffer(mtl, offset: 0, index: idx) }
        }
        enc.dispatchThreadgroups(MTLSize(width: x, height: y, depth: z),
                                 threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
    }

    func glFlush() {
        endPass()
        cmd?.commit()
        cmd = nil
    }

    func glFinish() {
        endPass()
        if let cb = cmd { cb.commit(); cb.waitUntilCompleted(); cmd = nil }
    }

    func glGetError() -> UInt32 { return 0 }

    func glGetString(_ name: UInt32) -> String {
        if name == GL_VERSION { return "4.1 (Hytale GL->Metal shim)" }
        return "Hytale GL->Metal"
    }

    private func beginEncoder() {
        guard encoder == nil else { return }
        let rpd: MTLRenderPassDescriptor
        if currentFBO != 0, let fbo = framebuffers[currentFBO], !fbo.colors.isEmpty {
            rpd = MTLRenderPassDescriptor()
            var formats: [MTLPixelFormat] = []
            var samples = 1
            for (i, texId) in fbo.colors.enumerated() {
                guard let gt = textures[texId] else { continue }
                rpd.colorAttachments[i].texture = gt.texture
                rpd.colorAttachments[i].loadAction = .clear
                rpd.colorAttachments[i].clearColor = clearColor
                if let resolve = gt.resolve {
                    rpd.colorAttachments[i].resolveTexture = resolve
                    rpd.colorAttachments[i].storeAction = .multisampleResolve
                    formats.append(resolve.pixelFormat)
                    samples = max(samples, gt.sampleCount)
                } else {
                    rpd.colorAttachments[i].storeAction = .store
                    formats.append(gt.texture.pixelFormat)
                }
            }
            if let d = fbo.depthTexture {
                rpd.depthAttachment.texture = d
                rpd.depthAttachment.loadAction = .clear
                rpd.depthAttachment.clearDepth = clearDepth
                rpd.depthAttachment.storeAction = d.sampleCount > 1 ? .dontCare : .store
            }
            currentTarget = RenderTarget(colors: formats, depth: fbo.depthTexture != nil ? .depth32Float : nil, samples: samples)
            targetHeight = formats.isEmpty ? 0 : Int(textures[fbo.colors[0]]?.texture.height ?? 0)
            targetWidth = formats.isEmpty ? 0 : Int(textures[fbo.colors[0]]?.texture.width ?? 0)
            lastPassDefault = false
        } else {
            guard let view = view, let v = view.currentRenderPassDescriptor else { return }
            v.colorAttachments[0].loadAction = .clear
            v.colorAttachments[0].clearColor = clearColor
            v.colorAttachments[0].storeAction = .store
            if let da = v.depthAttachment {
                da.loadAction = .clear
                da.clearDepth = clearDepth
                da.storeAction = .store
            }
            rpd = v
            currentTarget = RenderTarget(colors: [view.colorPixelFormat],
                                         depth: view.depthStencilPixelFormat == .invalid ? nil : view.depthStencilPixelFormat)
            targetHeight = Int(view.drawableSize.height)
            targetWidth = Int(view.drawableSize.width)
            lastPassDefault = true
        }
        if activeQuery != 0, let q = queries[activeQuery] {
            rpd.visibilityResultBuffer = q.buffer
        }
        if cmd == nil { cmd = queue.makeCommandBuffer() }
        encoder = cmd?.makeRenderCommandEncoder(descriptor: rpd)
        if activeQuery != 0 {
            encoder?.setVisibilityResultMode(.counting, offset: 0)
        }
    }

    private func endPass() { encoder?.endEncoding(); encoder = nil }

    func glEndFrame() {
        endPass()
        guard let cb = cmd else { return }
        if lastPassDefault, let drawable = view?.currentDrawable { cb.present(drawable) }
        cb.commit()
        cmd = nil
    }

    private func depthState() -> MTLDepthStencilState {
        let key = "\(depthTest)\(depthWrite)\(depthFunc)"
        if let s = depthStates[key] { return s }
        let d = MTLDepthStencilDescriptor()
        d.isDepthWriteEnabled = depthWrite
        if !depthTest { d.depthCompareFunction = .always; let s = device.makeDepthStencilState(descriptor: d)!; depthStates[key] = s; return s }
        switch depthFunc {
        case GL_LEQUAL: d.depthCompareFunction = .lessEqual
        case GL_ALWAYS: d.depthCompareFunction = .always
        default: d.depthCompareFunction = .less
        }
        let s = device.makeDepthStencilState(descriptor: d)!
        depthStates[key] = s
        return s
    }

    private func pipeline(_ prog: GLProgram, _ vao: GLVAO, _ target: RenderTarget) -> MTLRenderPipelineState? {
        let attrKey = vao.attribs.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value.size)@\($0.value.offset)" }.joined(separator: ",")
        let key = "\(blend)\(blendSrc)\(blendDst)|\(attrKey)|\(target.key)"
        if let p = prog.pipeline, prog.pipelineKey == key { return p }
        guard let vLib = prog.vertexLib, let fLib = prog.fragmentLib,
              let vFn = vLib.makeFunction(name: "main0"),
              let fFn = fLib.makeFunction(name: "main0") else { return nil }

        let vd = MTLVertexDescriptor()
        var stride = 32
        var instStride = 0
        for (i, a) in vao.attribs.sorted(by: { $0.key < $1.key }) {
            vd.attributes[i].format = (a.size == 3) ? .float3 : .float2
            vd.attributes[i].offset = a.offset
            vd.attributes[i].bufferIndex = a.divisor > 0 ? 9 : 8
            if a.divisor > 0 { instStride = a.stride } else if a.stride > 0 { stride = a.stride }
        }
        vd.layouts[8].stride = stride
        vd.layouts[8].stepFunction = .perVertex
        if instStride > 0 {
            vd.layouts[9].stride = instStride
            vd.layouts[9].stepFunction = .perInstance
        }

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vFn
        pd.fragmentFunction = fFn
        pd.vertexDescriptor = vd
        pd.rasterSampleCount = target.samples
        for (i, f) in target.colors.enumerated() { pd.colorAttachments[i].pixelFormat = f }
        if let d = target.depth { pd.depthAttachmentPixelFormat = d }
        if blend {
            let a = pd.colorAttachments[0]!
            a.isBlendingEnabled = true
            a.rgbBlendOperation = .add
            a.alphaBlendOperation = .add
            a.sourceRGBBlendFactor = blendFactor(blendSrc)
            a.destinationRGBBlendFactor = blendFactor(blendDst)
            a.sourceAlphaBlendFactor = blendFactor(blendSrc)
            a.destinationAlphaBlendFactor = blendFactor(blendDst)
        }
        do {
            let ps = try device.makeRenderPipelineState(descriptor: pd)
            prog.pipeline = ps
            prog.pipelineKey = key
            return ps
        } catch {
            HUD.shared.log("pipeline error: \(error)")
            return nil
        }
    }

    private func blendFactor(_ f: UInt32) -> MTLBlendFactor {
        switch f {
        case 1: return .one
        case 0: return .zero
        case GL_ONE_MINUS_SRC_ALPHA: return .oneMinusSourceAlpha
        case GL_DST_COLOR: return .destinationColor
        case GL_ONE_MINUS_DST_COLOR: return .oneMinusDestinationColor
        default: return .sourceAlpha
        }
    }

    private func applyViewport(_ enc: MTLRenderCommandEncoder) {
        if let vp = vpRect {
            let y = targetHeight - vp.1 - vp.3
            enc.setViewport(MTLViewport(originX: Double(vp.0), originY: Double(y),
                                        width: Double(vp.2), height: Double(vp.3), znear: 0, zfar: 1))
        }
        if scissorOn {
            let y = targetHeight - scissorRect.1 - scissorRect.3
            enc.setScissorRect(MTLScissorRect(x: scissorRect.0, y: y, width: scissorRect.2, height: scissorRect.3))
        } else if targetWidth > 0 && targetHeight > 0 {
            enc.setScissorRect(MTLScissorRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
    }

    private func bindCommon(_ enc: MTLRenderCommandEncoder) {
        applyViewport(enc)
        if let u = vertexBytes[currentProgram] {
            for (idx, bytes) in u {
                bytes.withUnsafeBytes { raw in
                    if let p = raw.baseAddress, bytes.count > 0 { enc.setVertexBytes(p, length: bytes.count, index: idx) }
                }
            }
        }
        if let u = fragmentBytes[currentProgram] {
            for (idx, bytes) in u {
                bytes.withUnsafeBytes { raw in
                    if let p = raw.baseAddress, bytes.count > 0 { enc.setFragmentBytes(p, length: bytes.count, index: idx) }
                }
            }
        }
        for (unit, texId) in boundTextures {
            if let t = textures[texId] {
                enc.setFragmentTexture(t.texture, index: unit)
                enc.setFragmentSamplerState(sampler(for: t), index: unit)
            }
        }
        enc.setCullMode(cullFace ? (cullFaceMode == GL_FRONT ? .front : .back) : .none)
        enc.setFrontFacing(frontFace == GL_CCW ? .counterClockwise : .clockwise)
    }

    func glDrawArrays(_ mode: UInt32, _ first: Int, _ count: Int, _ instanceCount: Int = 1) {
        beginEncoder()
        guard let enc = encoder, let prog = programs[currentProgram], let vao = vaos[currentVAO] else { return }
        guard let ps = pipeline(prog, vao, currentTarget) else { return }
        enc.setRenderPipelineState(ps)
        enc.setDepthStencilState(depthState())
        for (_, a) in vao.attribs where a.divisor == 0 {
            if let mtl = buffers[a.buffer] { enc.setVertexBuffer(mtl, offset: 0, index: 8) }
        }
        for (_, a) in vao.attribs where a.divisor > 0 {
            if let mtl = buffers[a.buffer] { enc.setVertexBuffer(mtl, offset: 0, index: 9) }
        }
        bindCommon(enc)
        enc.drawPrimitives(type: .triangle, vertexStart: first, vertexCount: count, instanceCount: instanceCount)
        drawCalls += 1
    }

    func glDrawElementsInstanced(_ mode: UInt32, _ count: Int, _ type: UInt32, _ offset: Int, _ inst: Int) {
        glDrawElements(mode, count, type, offset, inst)
    }

    func glDrawElements(_ mode: UInt32, _ count: Int, _ type: UInt32, _ offset: Int, _ instanceCount: Int = 1) {
        beginEncoder()
        guard let enc = encoder else { if !loggedSkip { loggedSkip = true; HUD.shared.log("skip: no encoder") }; return }
        guard let prog = programs[currentProgram] else { if !loggedSkip { loggedSkip = true; HUD.shared.log("skip: no program") }; return }
        guard let vao = vaos[currentVAO] else { if !loggedSkip { loggedSkip = true; HUD.shared.log("skip: no vao") }; return }
        guard let ibo = buffers[vao.elementBuffer] else {
            if !loggedSkip { loggedSkip = true; HUD.shared.log("skip: no ibo \(vao.elementBuffer) bufs=\(buffers.count)") }
            return
        }
        guard let ps = pipeline(prog, vao, currentTarget) else {
            if !loggedSkip { loggedSkip = true; HUD.shared.log("skip: no pipeline") }
            return
        }
        enc.setRenderPipelineState(ps)
        enc.setDepthStencilState(depthState())
        for (_, a) in vao.attribs where a.divisor == 0 {
            if let mtl = buffers[a.buffer] { enc.setVertexBuffer(mtl, offset: 0, index: 8) }
        }
        for (_, a) in vao.attribs where a.divisor > 0 {
            if let mtl = buffers[a.buffer] { enc.setVertexBuffer(mtl, offset: 0, index: 9) }
        }
        bindCommon(enc)
        enc.drawIndexedPrimitives(type: .triangle, indexCount: count, indexType: .uint32,
                                  indexBuffer: ibo, indexBufferOffset: offset, instanceCount: instanceCount)
        drawCalls += 1
    }
}

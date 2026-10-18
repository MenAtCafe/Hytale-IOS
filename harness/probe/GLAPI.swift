import Foundation

enum GLConst {
    static let ARRAY_BUFFER: UInt32 = 0x8892
    static let STATIC_DRAW: UInt32 = 0x88E4
    static let FLOAT: UInt32 = 0x1406
    static let TRIANGLES: UInt32 = 0x0004
    static let TEXTURE_2D: UInt32 = 0x0DE1
    static let RGBA8: Int32 = 0x8058
    static let RGBA: UInt32 = 0x1908
    static let UNSIGNED_BYTE: UInt32 = 0x1401
    static let FRAMEBUFFER: UInt32 = 0x8D40
    static let COLOR_ATTACHMENT0: UInt32 = 0x8CE0
    static let COLOR_BUFFER_BIT: UInt32 = 0x4000
    static let FRAMEBUFFER_COMPLETE: UInt32 = 0x8CD5
    static let VERTEX_SHADER: UInt32 = 0x8B31
    static let FRAGMENT_SHADER: UInt32 = 0x8B30
}

/// The subset of the 145-entry surface the probe needs, resolved through
/// SDL_GL_GetProcAddress exactly the way the client does.
struct GLAPI {
    let createShader: @convention(c) (UInt32) -> UInt32
    let shaderSource: @convention(c) (UInt32, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafePointer<Int32>?) -> Void
    let compileShader: @convention(c) (UInt32) -> Void
    let createProgram: @convention(c) () -> UInt32
    let attachShader: @convention(c) (UInt32, UInt32) -> Void
    let linkProgram: @convention(c) (UInt32) -> Void
    let useProgram: @convention(c) (UInt32) -> Void
    let genBuffers: @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
    let bindBuffer: @convention(c) (UInt32, UInt32) -> Void
    let bufferData: @convention(c) (UInt32, Int, UnsafeRawPointer?, UInt32) -> Void
    let genVertexArrays: @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
    let bindVertexArray: @convention(c) (UInt32) -> Void
    let enableVertexAttribArray: @convention(c) (UInt32) -> Void
    let vertexAttribPointer: @convention(c) (UInt32, Int32, UInt32, UInt8, Int32, UnsafeRawPointer?) -> Void
    let genTextures: @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
    let bindTexture: @convention(c) (UInt32, UInt32) -> Void
    let texImage2D: @convention(c) (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeRawPointer?) -> Void
    let genFramebuffers: @convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void
    let bindFramebuffer: @convention(c) (UInt32, UInt32) -> Void
    let framebufferTexture2D: @convention(c) (UInt32, UInt32, UInt32, UInt32, Int32) -> Void
    let checkFramebufferStatus: @convention(c) (UInt32) -> UInt32
    let viewport: @convention(c) (Int32, Int32, Int32, Int32) -> Void
    let clearColor: @convention(c) (Float, Float, Float, Float) -> Void
    let clear: @convention(c) (UInt32) -> Void
    let drawArrays: @convention(c) (UInt32, Int32, Int32) -> Void
    let readPixels: @convention(c) (Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeMutableRawPointer?) -> Void
    let endFrame: @convention(c) () -> Void
    let finish: @convention(c) () -> Void

    init?(_ getProc: GetProcAddressFn) {
        func s<T>(_ name: String, _ type: T.Type) -> T? {
            GLResolve.symbol(name, getProc, type)
        }
        guard
            let createShader = s("glCreateShader", (@convention(c) (UInt32) -> UInt32).self),
            let shaderSource = s("glShaderSource", (@convention(c) (UInt32, Int32, UnsafePointer<UnsafePointer<CChar>?>?, UnsafePointer<Int32>?) -> Void).self),
            let compileShader = s("glCompileShader", (@convention(c) (UInt32) -> Void).self),
            let createProgram = s("glCreateProgram", (@convention(c) () -> UInt32).self),
            let attachShader = s("glAttachShader", (@convention(c) (UInt32, UInt32) -> Void).self),
            let linkProgram = s("glLinkProgram", (@convention(c) (UInt32) -> Void).self),
            let useProgram = s("glUseProgram", (@convention(c) (UInt32) -> Void).self),
            let genBuffers = s("glGenBuffers", (@convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void).self),
            let bindBuffer = s("glBindBuffer", (@convention(c) (UInt32, UInt32) -> Void).self),
            let bufferData = s("glBufferData", (@convention(c) (UInt32, Int, UnsafeRawPointer?, UInt32) -> Void).self),
            let genVertexArrays = s("glGenVertexArrays", (@convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void).self),
            let bindVertexArray = s("glBindVertexArray", (@convention(c) (UInt32) -> Void).self),
            let enableVertexAttribArray = s("glEnableVertexAttribArray", (@convention(c) (UInt32) -> Void).self),
            let vertexAttribPointer = s("glVertexAttribPointer", (@convention(c) (UInt32, Int32, UInt32, UInt8, Int32, UnsafeRawPointer?) -> Void).self),
            let genTextures = s("glGenTextures", (@convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void).self),
            let bindTexture = s("glBindTexture", (@convention(c) (UInt32, UInt32) -> Void).self),
            let texImage2D = s("glTexImage2D", (@convention(c) (UInt32, Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeRawPointer?) -> Void).self),
            let genFramebuffers = s("glGenFramebuffers", (@convention(c) (Int32, UnsafeMutablePointer<UInt32>?) -> Void).self),
            let bindFramebuffer = s("glBindFramebuffer", (@convention(c) (UInt32, UInt32) -> Void).self),
            let framebufferTexture2D = s("glFramebufferTexture2D", (@convention(c) (UInt32, UInt32, UInt32, UInt32, Int32) -> Void).self),
            let checkFramebufferStatus = s("glCheckFramebufferStatus", (@convention(c) (UInt32) -> UInt32).self),
            let viewport = s("glViewport", (@convention(c) (Int32, Int32, Int32, Int32) -> Void).self),
            let clearColor = s("glClearColor", (@convention(c) (Float, Float, Float, Float) -> Void).self),
            let clear = s("glClear", (@convention(c) (UInt32) -> Void).self),
            let drawArrays = s("glDrawArrays", (@convention(c) (UInt32, Int32, Int32) -> Void).self),
            let readPixels = s("glReadPixels", (@convention(c) (Int32, Int32, Int32, Int32, UInt32, UInt32, UnsafeMutableRawPointer?) -> Void).self),
            let endFrame = s("glEndFrame", (@convention(c) () -> Void).self),
            let finish = s("glFinish", (@convention(c) () -> Void).self)
        else {
            return nil
        }
        self.createShader = createShader
        self.shaderSource = shaderSource
        self.compileShader = compileShader
        self.createProgram = createProgram
        self.attachShader = attachShader
        self.linkProgram = linkProgram
        self.useProgram = useProgram
        self.genBuffers = genBuffers
        self.bindBuffer = bindBuffer
        self.bufferData = bufferData
        self.genVertexArrays = genVertexArrays
        self.bindVertexArray = bindVertexArray
        self.enableVertexAttribArray = enableVertexAttribArray
        self.vertexAttribPointer = vertexAttribPointer
        self.genTextures = genTextures
        self.bindTexture = bindTexture
        self.texImage2D = texImage2D
        self.genFramebuffers = genFramebuffers
        self.bindFramebuffer = bindFramebuffer
        self.framebufferTexture2D = framebufferTexture2D
        self.checkFramebufferStatus = checkFramebufferStatus
        self.viewport = viewport
        self.clearColor = clearColor
        self.clear = clear
        self.drawArrays = drawArrays
        self.readPixels = readPixels
        self.endFrame = endFrame
        self.finish = finish
    }
}

import Foundation
import Metal
import MetalKit

// Process-global GL context used by the C ABI layer.
let gDevice = MTLCreateSystemDefaultDevice()!
let gGL = GLContext(device: gDevice, view: nil)

private let logPath = "/tmp/hytalegl.log"

private func glog(_ s: String) {
    let line = s + "\n"
    if let fh = FileHandle(forWritingAtPath: logPath) {
        fh.seekToEndOfFile(); fh.write(line.data(using: .utf8)!); fh.closeFile()
    } else {
        try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - buffer objects

@_cdecl("glGenBuffers")
public func glGenBuffers(_ n: Int32, _ ids: UnsafeMutablePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { ids[i] = gGL.glGenBuffers() }
}

@_cdecl("glBindBuffer")
public func glBindBuffer(_ target: UInt32, _ id: UInt32) { gGL.glBindBuffer(target, id) }

@_cdecl("glBufferData")
public func glBufferData(_ target: UInt32, _ size: Int, _ data: UnsafeRawPointer?, _ usage: UInt32) {
    guard let data = data else { return }
    gGL.glBufferData(target, data, size, usage)
}

@_cdecl("glMapBufferRange")
public func glMapBufferRange(_ target: UInt32, _ offset: Int, _ length: Int, _ access: UInt32) -> UnsafeMutableRawPointer? {
    return gGL.glMapBufferRange(target, offset, length, access)
}

@_cdecl("glUnmapBuffer")
public func glUnmapBuffer(_ target: UInt32) -> UInt8 { return gGL.glUnmapBuffer(target) ? 1 : 0 }

// MARK: - shaders

@_cdecl("glCreateShader")
public func glCreateShader(_ type: UInt32) -> UInt32 { return gGL.glCreateShader(type) }

@_cdecl("glShaderSource")
public func glShaderSource(_ shader: UInt32, _ count: Int32,
                           _ strings: UnsafePointer<UnsafePointer<CChar>?>?,
                           _ lengths: UnsafePointer<Int32>?) {
    guard let strings = strings else { return }
    var src = ""
    for i in 0..<Int(count) {
        if let s = strings[i] { src += String(cString: s) }
    }
    gGL.glShaderSource(shader, src)
}

@_cdecl("glCompileShader")
public func glCompileShader(_ shader: UInt32) { gGL.glCompileShader(shader) }

@_cdecl("glCreateProgram")
public func glCreateProgram() -> UInt32 { return gGL.glCreateProgram() }

@_cdecl("glAttachShader")
public func glAttachShader(_ program: UInt32, _ shader: UInt32) { gGL.glAttachShader(program, shader) }

@_cdecl("glLinkProgram")
public func glLinkProgram(_ program: UInt32) { gGL.glLinkProgram(program) }

@_cdecl("glUseProgram")
public func glUseProgram(_ program: UInt32) { gGL.glUseProgram(program) }

// MARK: - uniforms

@_cdecl("glGetUniformLocation")
public func glGetUniformLocation(_ program: UInt32, _ name: UnsafePointer<CChar>?) -> Int32 {
    guard let name = name else { return -1 }
    return Int32(gGL.glGetUniformLocation(program, String(cString: name)))
}

@_cdecl("glUniformMatrix4fv")
public func glUniformMatrix4fv(_ location: Int32, _ count: Int32, _ transpose: UInt8,
                               _ value: UnsafePointer<simd_float4x4>?) {
    guard let value = value else { return }
    gGL.glUniformMatrix4fv(Int(location), Int(count), transpose != 0, value)
}

// MARK: - VAO / attribs

@_cdecl("glGenVertexArrays")
public func glGenVertexArrays(_ n: Int32, _ ids: UnsafeMutablePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { ids[i] = gGL.glGenVertexArrays() }
}

@_cdecl("glBindVertexArray")
public func glBindVertexArray(_ id: UInt32) { gGL.glBindVertexArray(id) }

@_cdecl("glEnableVertexAttribArray")
public func glEnableVertexAttribArray(_ index: UInt32) { gGL.glEnableVertexAttribArray(Int(index)) }

@_cdecl("glVertexAttribPointer")
public func glVertexAttribPointer(_ index: UInt32, _ size: Int32, _ type: UInt32,
                                  _ normalized: UInt8, _ stride: Int32,
                                  _ pointer: UnsafeRawPointer?) {
    gGL.glVertexAttribPointer(Int(index), Int(size), type, normalized != 0,
                              Int(stride), Int(bitPattern: pointer))
}

@_cdecl("glVertexAttribDivisor")
public func glVertexAttribDivisor(_ index: UInt32, _ divisor: UInt32) {
    gGL.glVertexAttribDivisor(Int(index), Int(divisor))
}

// MARK: - textures

@_cdecl("glGenTextures")
public func glGenTextures(_ n: Int32, _ ids: UnsafeMutablePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { ids[i] = gGL.glGenTextures() }
}

@_cdecl("glBindTexture")
public func glBindTexture(_ target: UInt32, _ id: UInt32) { gGL.glBindTexture(target, id) }

@_cdecl("glTexImage2D")
public func glTexImage2D(_ target: UInt32, _ level: Int32, _ internalFormat: Int32,
                         _ width: Int32, _ height: Int32, _ border: Int32,
                         _ format: UInt32, _ type: UInt32, _ pixels: UnsafeRawPointer?) {
    gGL.glTexImage2D(target, Int(level), Int(internalFormat), Int(width), Int(height),
                     Int(border), format, type, pixels)
}

@_cdecl("glTexParameteri")
public func glTexParameteri(_ target: UInt32, _ pname: UInt32, _ param: UInt32) {
    gGL.glTexParameteri(target, pname, param)
}

// MARK: - framebuffers

@_cdecl("glGenFramebuffers")
public func glGenFramebuffers(_ n: Int32, _ ids: UnsafeMutablePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { ids[i] = gGL.glGenFramebuffers() }
}

@_cdecl("glBindFramebuffer")
public func glBindFramebuffer(_ target: UInt32, _ id: UInt32) { gGL.glBindFramebuffer(target, id) }

@_cdecl("glFramebufferTexture2D")
public func glFramebufferTexture2D(_ target: UInt32, _ attachment: UInt32, _ textarget: UInt32,
                                   _ texture: UInt32, _ level: Int32) {
    gGL.glFramebufferTexture2D(target, attachment, textarget, texture, Int(level))
}

// MARK: - state + draws

@_cdecl("glEnable")
public func glEnable(_ cap: UInt32) { gGL.glEnable(cap) }

@_cdecl("glDisable")
public func glDisable(_ cap: UInt32) { gGL.glDisable(cap) }

@_cdecl("glDepthFunc")
public func glDepthFunc(_ f: UInt32) { gGL.glDepthFunc(f) }

@_cdecl("glClearColor")
public func glClearColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
    gGL.glClearColor(r, g, b, a)
}

@_cdecl("glClear")
public func glClear(_ mask: UInt32) { gGL.glClear(mask) }

@_cdecl("glViewport")
public func glViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) {
    gGL.glViewport(Int(x), Int(y), Int(w), Int(h))
}

@_cdecl("glDrawArrays")
public func glDrawArrays(_ mode: UInt32, _ first: Int32, _ count: Int32) {
    gGL.glDrawArrays(mode, Int(first), Int(count))
}

@_cdecl("glDrawElements")
public func glDrawElements(_ mode: UInt32, _ count: Int32, _ type: UInt32, _ indices: UnsafeRawPointer?) {
    gGL.glDrawElements(mode, Int(count), type, Int(bitPattern: indices))
}

// MARK: - info

@_cdecl("glGetError")
public func glGetError() -> UInt32 { return gGL.glGetError() }

private let versionCString = strdup("4.1 (Hytale GL->Metal shim)")

@_cdecl("glGetString")
public func glGetString(_ name: UInt32) -> UnsafePointer<CChar>? {
    return UnsafePointer(versionCString)
}


// MARK: - queries

@_cdecl("glGenQueries")
public func glGenQueries(_ n: Int32, _ ids: UnsafeMutablePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { ids[i] = gGL.glGenQueries() }
}

@_cdecl("glDeleteQueries")
public func glDeleteQueries(_ n: Int32, _ ids: UnsafePointer<UInt32>?) {
    guard let ids = ids else { return }
    for i in 0..<Int(n) { gGL.glDeleteQueries(ids[i]) }
}

@_cdecl("glBeginQuery")
public func glBeginQuery(_ target: UInt32, _ id: UInt32) { gGL.glBeginQuery(target, id) }

@_cdecl("glEndQuery")
public func glEndQuery(_ target: UInt32) { gGL.glEndQuery(target) }

@_cdecl("glGetQueryObjectuiv")
public func glGetQueryObjectuiv(_ id: UInt32, _ pname: UInt32, _ params: UnsafeMutablePointer<UInt32>?) {
    params?.pointee = gGL.glGetQueryObjectuiv(id, pname)
}

// MARK: - fences

@_cdecl("glFenceSync")
public func glFenceSync(_ condition: UInt32, _ flags: UInt32) -> UnsafeMutableRawPointer? {
    return UnsafeMutableRawPointer(bitPattern: Int(gGL.glFenceSync(condition, flags)))
}

@_cdecl("glClientWaitSync")
public func glClientWaitSync(_ sync: UnsafeMutableRawPointer?, _ flags: UInt32, _ timeout: UInt64) -> UInt32 {
    guard let sync = sync else { return 0x911D }
    return gGL.glClientWaitSync(UInt32(UInt(bitPattern: sync)), flags, timeout)
}

@_cdecl("glDeleteSync")
public func glDeleteSync(_ sync: UnsafeMutableRawPointer?) {
    if let sync = sync { gGL.glDeleteSync(UInt32(UInt(bitPattern: sync))) }
}

@_cdecl("glIsSync")
public func glIsSync(_ sync: UnsafeMutableRawPointer?) -> UInt8 {
    guard let sync = sync else { return 0 }
    return gGL.glIsSync(UInt32(UInt(bitPattern: sync))) ? 1 : 0
}

// MARK: - MSAA

@_cdecl("glTexImage2DMultisample")
public func glTexImage2DMultisample(_ target: UInt32, _ samples: Int32, _ internalformat: Int32,
                                    _ width: Int32, _ height: Int32, _ fixedsamplelocations: UInt8) {
    gGL.glTexImage2DMultisample(target, Int(samples), Int(internalformat),
                                Int(width), Int(height), fixedsamplelocations != 0)
}

@_cdecl("glGetResolvedTexture")
public func glGetResolvedTexture(_ id: UInt32) -> UInt32 { return gGL.glGetResolvedTexture(id) }

// MARK: - state extras

@_cdecl("glScissor")
public func glScissor(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) { gGL.glScissor(Int(x), Int(y), Int(w), Int(h)) }

@_cdecl("glBlendFunc")
public func glBlendFunc(_ s: UInt32, _ d: UInt32) { gGL.glBlendFunc(s, d) }

@_cdecl("glDepthMask")
public func glDepthMask(_ flag: UInt8) { gGL.glDepthMask(flag != 0) }

@_cdecl("glClearDepth")
public func glClearDepth(_ d: Double) { gGL.glClearDepth(d) }

@_cdecl("glActiveTexture")
public func glActiveTexture(_ unit: UInt32) { gGL.glActiveTexture(unit) }

@_cdecl("glFinish")
public func glFinish() { gGL.glFinish() }

@_cdecl("glFlush")
public func glFlush() { gGL.glFlush() }

// MARK: - instanced draws

@_cdecl("glDrawArraysInstanced")
public func glDrawArraysInstanced(_ mode: UInt32, _ first: Int32, _ count: Int32, _ instances: Int32) {
    gGL.glDrawArrays(mode, Int(first), Int(count), Int(instances))
}

@_cdecl("glDrawElementsInstanced")
public func glDrawElementsInstanced(_ mode: UInt32, _ count: Int32, _ type: UInt32,
                                    _ indices: UnsafeRawPointer?, _ instances: Int32) {
    gGL.glDrawElements(mode, Int(count), type, Int(bitPattern: indices), Int(instances))
}

// MARK: - readback / compute

@_cdecl("glReadPixels")
public func glReadPixels(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32,
                         _ format: UInt32, _ type: UInt32, _ pixels: UnsafeMutableRawPointer?) {
    guard let pixels = pixels else { return }
    gGL.glReadPixels(Int(x), Int(y), Int(w), Int(h), format, type, pixels)
}

@_cdecl("glGetBufferSubData")
public func glGetBufferSubData(_ target: UInt32, _ offset: Int, _ size: Int, _ data: UnsafeMutableRawPointer?) {
    guard let data = data else { return }
    gGL.glGetBufferSubData(target, offset, size, data)
}

@_cdecl("glBindBufferBase")
public func glBindBufferBase(_ target: UInt32, _ index: UInt32, _ buffer: UInt32) {
    gGL.glBindBufferBase(target, Int(index), buffer)
}

@_cdecl("glDispatchCompute")
public func glDispatchCompute(_ x: Int32, _ y: Int32, _ z: Int32) {
    gGL.glDispatchCompute(Int(x), Int(y), Int(z))
}

// MARK: - deletes (safe no-ops for now)

@_cdecl("glDeleteBuffers")
public func glDeleteBuffers(_ n: Int32, _ ids: UnsafePointer<UInt32>?) {}
@_cdecl("glDeleteTextures")
public func glDeleteTextures(_ n: Int32, _ ids: UnsafePointer<UInt32>?) {}
@_cdecl("glDeleteProgram")
public func glDeleteProgram(_ p: UInt32) {}
@_cdecl("glDeleteShader")
public func glDeleteShader(_ s: UInt32) {}

// MARK: - hook

// MARK: - harness wire-up (M0)

/// Bind the probe's MTKView to the process-global GL context.
/// Takes an unretained MTKView pointer; the caller keeps it alive.
@_cdecl("HytaleGL_AttachView")
public func HytaleGL_AttachView(_ opaque: UnsafeMutableRawPointer?) {
    guard let opaque = opaque else {
        gGL.attachView(nil)
        glog("HytaleGL_AttachView nil")
        return
    }
    let view = Unmanaged<MTKView>.fromOpaque(opaque).takeUnretainedValue()
    gGL.attachView(view)
    glog("HytaleGL_AttachView \(Int(view.drawableSize.width))x\(Int(view.drawableSize.height))")
}

@_cdecl("glEndFrame")
public func glEndFrame() { gGL.glEndFrame() }

@_cdecl("glCullFace")
public func glCullFace(_ mode: UInt32) { gGL.glCullFace(mode) }

@_cdecl("glFrontFace")
public func glFrontFace(_ mode: UInt32) { gGL.glFrontFace(mode) }

@_cdecl("glCheckFramebufferStatus")
public func glCheckFramebufferStatus(_ target: UInt32) -> UInt32 {
    gGL.glCheckFramebufferStatus(target)
}

@_cdecl("glUniform1f")
public func glUniform1f(_ location: Int32, _ v: Float) { gGL.glUniform1f(Int(location), v) }

@_cdecl("glUniform1i")
public func glUniform1i(_ location: Int32, _ v: Int32) { gGL.glUniform1i(Int(location), v) }

@_cdecl("glUniform4f")
public func glUniform4f(_ location: Int32, _ x: Float, _ y: Float, _ z: Float, _ w: Float) {
    gGL.glUniform4f(Int(location), x, y, z, w)
}

@_cdecl("HytaleGL_GetProcAddress")
public func HytaleGL_GetProcAddress(_ name: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let name = name else { return nil }
    let s = String(cString: name)
    glog("GLPROC " + s)
    return hytaleGL_resolve(s)
}

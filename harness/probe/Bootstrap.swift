import Foundation
import MetalKit

typealias GetProcAddressFn = @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?

struct ProbeEnv {
    let getProc: GetProcAddressFn
}

enum ProbeError: Error, CustomStringConvertible {
    case fatal(String)

    var description: String {
        switch self {
        case .fatal(let message): return message
        }
    }
}

enum Bootstrap {
    /// Load the patched SDL3 from the bundle. Its constructor preloads
    /// libHytaleGL.dylib from the same directory, so by the time this
    /// returns, the whole HytaleClient -> SDL3 -> libHytaleGL chain exists.
    static func load() throws -> ProbeEnv {
        let sdlPath = Bundle.main.bundlePath + "/SDL3.dylib"
        guard let handle = dlopen(sdlPath, RTLD_NOW | RTLD_LOCAL) else {
            throw ProbeError.fatal("dlopen(SDL3): \(String(cString: dlerror()))")
        }
        guard let sym = dlsym(handle, "SDL_GL_GetProcAddress") else {
            throw ProbeError.fatal("dlsym(SDL_GL_GetProcAddress) failed")
        }
        return ProbeEnv(getProc: unsafeBitCast(sym, to: GetProcAddressFn.self))
    }

    /// Hand the shim's process-global GLContext a drawable.
    static func attach(_ view: MTKView) -> Bool {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "HytaleGL_AttachView") else {
            return false
        }
        typealias AttachFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
        let attach = unsafeBitCast(sym, to: AttachFn.self)
        attach(Unmanaged.passUnretained(view).toOpaque())
        return true
    }
}

enum GLResolve {
    static func symbol<T>(_ name: String, _ getProc: GetProcAddressFn, _ type: T.Type) -> T? {
        var result: T?
        name.withCString { cName in
            if let addr = getProc(cName) {
                result = unsafeBitCast(addr, to: T.self)
            }
        }
        return result
    }
}

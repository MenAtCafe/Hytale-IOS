> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. This document is a record of measurements, not a plan.

# Verdict: Hytale's GL surface vs iOS Metal

## 1. The live trace failed, and why

`gltrace.log` came back empty. The cause is the launcher, not the setup:

~~~text
trace.sh  ->  Hytale Launcher (f2p-evo)
                 flags = 0x10000  (hardened runtime)
                 entitlements = none
~~~

A hardened binary refuses `DYLD_INSERT_LIBRARIES`, and dyld **strips all `DYLD_*`
variables from the environment before the process starts**, so the child
`HytaleClient` never inherits the tracer either. The injection point is closed by
design.

Getting a live profile would require replacing the client in the install, attaching
a debugger at the right moment, or rebuilding the launcher. None were done: the
first modifies someone else's install, and the third defeats the purpose. Nothing
in the installation was modified.

## 2. What can be answered statically, and it's the important part

All 145 `gl*` names in the client are **the engine's loader table**: each one is a
string it passes to `SDL_GL_GetProcAddress`. Presence therefore means "the code can
call this", which is exactly the surface a GL→Metal driver must cover.

| Class | Count | Meaning |
|---|---|---|
| **Direct** | **97** | Metal has a close equivalent (buffers, VAOs, draws, samplers, textures, shader objects, uniforms, FBOs, blend/depth state) |
| **Glue** | **41** | Needs translation logic but is achievable (render-pass setup, UBO binding, blits, readbacks, fences, query objects, per-attachment blending, debug markers) |
| **Unsupported** | **7** | No iOS Metal path today |

### The 7

| Function(s) | Feature | Reality on iOS |
|---|---|---|
| `glBeginTransformFeedback`, `glEndTransformFeedback`, `glTransformFeedbackVaryings` | Transform feedback (GPU writes vertex results back to a buffer) | **Metal has no equivalent.** Emulated in `slice/` with a compute kernel |
| `glTexImage2DMultisample` | Multisampled textures | iOS Metal can render *to* MSAA targets but cannot **sample** MSAA textures; resolved into a sampleable texture instead |
| `glPolygonMode` | Wireframe fill | `MTLTriangleFillModeLines` is macOS-only |
| `glQueryCounter`, `glGetQueryObjectui64v` | GPU timestamp queries | GPU timers are not exposed on iOS |

Two of those four families are almost certainly debug/profiling paths (wireframe,
GPU timers). The other two, transform feedback and MSAA sampling, were the only
places where a real feature could have been missing rather than merely expensive,
and both were worked around.

## 3. What this changed

The GL layer was bounded here: 97 mechanical, 41 glue, 3 real gaps. No unknown
unknowns remained in the graphics API. What remained was execution, not discovery:
a GL→Metal driver, the app host, retargeting/signing, the asset budget, and the
Java server.

The driver was then built (`gate4/`, `slice/`, `harness/`). Measured reach at the
halt: **65 of 145** declared entry points resolve through the built dylib; 80 are
unimplemented. The project stopped at the launcher/account verification gate on
2026-10-18, which was not bypassed.

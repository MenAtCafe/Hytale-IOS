> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# Gate 4: routing the client's GL calls into the shim

## Architecture

~~~text
HytaleClient
   |  dlsym("SDL_GL_GetProcAddress")        (already what the client does)
   v
SDL3.dylib  (built by us, patched)
   |  SDL_GL_GetProcAddress()
   |  -> dlsym(RTLD_DEFAULT, "HytaleGL_GetProcAddress")  [hook]
   v
libHytaleGL.dylib  (C-ABI GL implementation over Metal)
   |  returns our function pointers, or NULL -> SDL falls back to the system GL
   v
Metal
~~~

No patching of the game binary: the client already resolves GL through SDL, and
we control the SDL it loads.

## What was verified at this gate

1. SDL3 patched at `SDL_GL_GetProcAddress` to consult the hook first.
2. `libHytaleGL.dylib` exports `HytaleGL_GetProcAddress`, `glCreateShader`,
   `glGetError` with C ABI (`@_cdecl` in Swift).
3. Test in the simulator:

~~~text
resolved glCreateShader -> 0x104af8fd0
call -> 42
resolved glDrawElements -> 0x0 (null = falls back to SDL)
=== log ===
GLPROC glCreateShader
GLPROC glDrawElements
~~~

That is the full chain: SDL → hook → our GL function, with graceful fallback for
unimplemented entry points.

## The profiler, and what happened to it

Every request is logged, so `/tmp/hytalegl.log` gives the dynamic set of GL
functions the client uses. The live profile was never captured, because the game
never gets past startup.

The harness (`harness/`) instead drives the same chain synthetically. It
regenerates the dispatch table from the Swift `@_cdecl` declarations, so the
hand-written switch and its 64 `@convention(c)` casts are gone.

## What was completed afterwards

1. `libHytaleGL` grew from 64 to **71** GL exports: the five implemented-but-
   unwired functions (`glCullFace`, `glFrontFace`, `glCheckFramebufferStatus`,
   `glUniform1f/1i/4f`; note `glCullFace` was a no-op until then) plus
   `glEndFrame` and `HytaleGL_AttachView`.
2. `HytaleGL_AttachView` binds an `MTKView` to the process-global
   `GLContext`. Without it the dylib is created with `view: nil` and can
   never present. That was a packaging bug this gate's README did not record.
3. The dispatch table is generated (`harness/gen/emit_switch.py`); the dylib
   must be built with `-whole-module-optimization`, or the `@_cdecl`
   thunks are emitted per file and the link fails with duplicate symbols.
4. Exact reach: **65 / 145** declared functions resolve through SDL. The other 80
   are unimplemented; there are no "wire-up" leftovers any more.

## Where it stopped

The project was halted on 2026-10-18. The remaining work, which covers the other 80 entry points, per-frame telemetry
and the app host, was not done.
See `harness/README.md` for the exact state and the one open bug.

> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. This document is a record of measurements, not a plan.

# Hytale → iOS: shader and GL-surface spike

**Date:** 2026-10-17
**Client:** Hytale 0.7.2, `HytaleClient` (Mach-O arm64, .NET 10 NativeAOT, platform macOS)

## Part 1: Shaders. Can they exist on iOS at all?

iOS has no desktop OpenGL, only Metal. So: take Hytale's shaders out of the binary
and push them through a real GLSL → Metal chain.

**Method**
1. The 68 shaders and 27 includes are plain UTF-8 text inside the binary
   (`HytaleClient.Graphics.Shaders.*.glsl`). Carved out by offset.
2. `glslang` 16.6.0: GLSL → SPIR-V (OpenGL semantics, auto-mapped locations/bindings).
3. `SPIRV-Cross`: SPIR-V → Metal Shading Language.
4. Nothing hand-edited to force a pass.

**Result**

| Outcome | Count |
|---|---|
| **Compiled to SPIR-V and emitted valid Metal** | **59 / 68 (87%)** |
| Remaining | 9, all carving artifacts (duplicated functions, a block cut mid-file, a shader whose `main` is behind an unset permutation guard) |
| Failed because Metal genuinely cannot express it | **0** |

~6,200 lines of Metal generated in `build/*.metal`.

**Conclusion:** the shader corpus is portable. The wall was never the shaders.

## Part 2: The GL call surface

145 distinct `gl*` entry points are resolved at runtime through
`SDL_GL_GetProcAddress`. See `GL-SURFACE.md` for the breakdown and the 13
functions needing real emulation design (`glTexBuffer`, `glDrawBuffers`,
`glBindImageTexture`, `glMapBufferRange`, ...).

**Live trace attempted and blocked.** `HytaleClient` refuses to start on its own
("Started without launcher arguments"), so the tracer was aimed at the launcher.
The launcher is Developer ID signed with **hardened runtime** (`flags=0x10000`) and
no entitlements, so dyld rejects `DYLD_INSERT_LIBRARIES` and strips `DYLD_*` from
the environment the game inherits. `gltrace.log` was empty for that reason; the
install was left untouched. The injection point is closed by design, and it was not
circumvented.

The static classification is therefore the result. See `VERDICT.md`:
**97 direct / 41 glue / 7 unsupported**. It was later superseded by a generated,
machine-readable manifest: **145 declared, 65 reachable** through the built dylib
(`harness/manifest/gl.json`).

## Part 3: Vertical slice, Hytale pixels on Metal

`slice/` contains a running iOS app that drives Metal through a GL-shaped API
and renders Hytale's own `BasicVS` + `BasicFS` with a block texture from
`Assets.zip`. It grew to 67 entry points, covering deferred rendering, 784-instance
draws, compute-emulated transform feedback, 4× MSAA, blending, scissor, fences and
readback.

**Two real translation bugs found:**

1. spirv-cross emitted `float3 outColor [[color(0)]]` because the GLSL declares
   `out vec3`. Metal requires the fragment output to cover the attachment
   format; widened to `float4` + `float4(color.xyz, 1.0)`. This is a driver
   responsibility, not a shader authoring error.
2. Xcode 27.1 shipped without the Metal toolchain component; runtime shader
   compilation failed until `xcodebuild -downloadComponent MetalToolchain`.

## Reproduce

The vendored glslang and SPIRV-Cross trees were removed to keep the repository
small; re-clone them first.

~~~sh
brew install glslang
git clone --depth 1 https://github.com/KhronosGroup/SPIRV-Cross
./tools/glslang/bin/glslang -G --auto-map-locations --auto-map-bindings \\
    -DKBUFFER_SLOTS=4 -DKERNEL_SIZE=3 -DNB_SAMPLES=16 \\
    build/s01.vert -o build/s01.spv
SPIRV-Cross/spirv-cross build/s01.spv --msl > build/s01.metal
~~~

## Where this stopped

The live dynamic profile was never captured: the game never gets past its launcher
verification, and that check was deliberately not bypassed. The project was halted
on 2026-10-18. The static surface plus the harness reachability measurement are the
final word on the graphics layer.

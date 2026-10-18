> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. This document is a record of measurements, not a plan.

# Hytale's OpenGL call surface (static)

145 distinct `gl*` entry points appear in `HytaleClient`. These are the "verbs"
the engine uses to talk to the GPU, resolved at runtime through
`SDL_GL_GetProcAddress`.

| Category | Count |
|---|---|
| State (blend/depth/cull/viewport/masks) | 30 |
| Misc (create/delete/get/flush) | 26 |
| Uniforms | 18 |
| Shaders | 17 |
| Textures | 16 |
| Framebuffers | 9 |
| Buffers | 7 |
| Vertex attributes | 7 |
| Queries | 6 |
| Draws | 4 |
| Sync (fences) | 3 |
| Image load/store | 2 |

## The 13 that needed real emulation work

Metal has no direct equivalent for these; each needs a design decision:

- `glTexBuffer`: buffer textures (Metal has `texture_buffer` on Apple GPUs)
- `glTexImage1D`: 1D textures (fold into 2D)
- `glDrawBuffer` / `glDrawBuffers` / `glReadBuffer`: render-pass attachment setup
- `glBindImageTexture` + `glMemoryBarrier`: image load/store
- `glBindBufferBase` / `glBindBufferRange`: UBO/SSBO binding
- `glUniformBlockBinding`: UBO slot mapping
- `glMapBufferRange`: buffer mapping (shared/managed buffers)
- `glBlitFramebuffer`: blit encoder
- `glCopyTexSubImage2D`: copy passes
- `glTexImage2DMultisample`: MSAA textures
- `glPolygonMode`, `glPointSize`: no Metal equivalent for line/point sizing

Everything else (draws, VAOs, samplers, textures, shader objects, uniforms, queries,
fences) maps mechanically onto Metal objects.

## Current standing

This page records the **static** classification. The authoritative, generated numbers
are in `harness/manifest/gl.json` and `harness/manifest/COVERAGE.md`:

| | |
|---|---|
| Declared | **145** |
| Reachable through `libHytaleGL.dylib` | **65** |
| Unimplemented | **80** |
| Exported extensions | **6** |
| `@_cdecl` GL exports | **71** |

Static presence is not per-frame usage. The dynamic profile was never captured,
because the client stops at its launcher verification before making a GL call, and
that check was not bypassed. The project was halted on 2026-10-18.

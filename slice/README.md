> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# HytaleSlice: GL→Metal renderer

Deferred, instanced, blended, scissored, synchronized, compute-emulated transform
feedback, buffer readback, 4× MSAA with resolve.

## MSAA status

The MSAA path works end to end; 4× sample counts confirm it (1.7M → ~6.9M
occlusion samples), and both attachments resolve correctly.

**The albedo-dark bug was fixed.** The root cause was a missing
`rasterSampleCount` on the pipeline: 4-sample textures were being written by
a 1-sample pipeline, so the resolve averaged one real sample with three cleared
ones (~25% brightness). The fix was one line plus carrying the sample count
through the render-target descriptor and pipeline cache key.

- `msaa-final.png` is the **dark pre-fix** frame, kept for comparison.
- `msaa-fixed.png` is the corrected frame.

This README previously reported the albedo resolve as an open multi-attachment
bug. That diagnosis was wrong.

## Everything else

- deferred GBuffer with 2 MRT
- 784-instance opaque pass, occlusion query
- composite with N·L lighting
- viewport/scissor picture-in-picture (with fixed scissor reset)
- forward transparency, real blend state
- 4000-particle compute pass (transform-feedback emulation)
- buffer mapping / readback, fences

## GL surface: 67 entry points

The slice implements 67 entry points for its own scenes. That is a measure of the
standalone renderer, not of the client's surface: the authoritative count is
145 declared / 65 reachable via the dylib (`harness/manifest/gl.json`).

## Where it stopped

This app still builds and runs, and is the reference implementation for the
shim's behaviour. The project was halted on 2026-10-18; no further renderer work
is planned.

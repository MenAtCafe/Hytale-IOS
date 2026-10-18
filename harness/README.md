> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# harness: GL surface manifest, generated dispatch, and probe

Built as milestones 0–1 of the record/replay plan. It exists to answer three
questions separately, instead of conflating them:

| Question | How it is measured | Result at halt |
|---|---|---|
| **Reachable**: does `SDL_GL_GetProcAddress` return non-NULL? | resolve every manifest name through the real SDL | **65 / 145** |
| **Callable**: does the call survive valid inputs? | one triangle through the dylib | **yes**, no crash |
| **Conformant**: does it produce the right pixels? | FBO readback vs clear colour | **no**, `nonBackground: 0` |

## Layout

~~~text
harness/
  manifest/
    gen_manifest.py       gl-surface.json + gl3.h + nm + GLShim.swift -> gl.json
    overrides.json        the 7 GL 4.2+ prototypes macOS gl3.h lacks, plus extensions
    gl.json               generated manifest (5 consumers)
    COVERAGE.md           generated matrix, per group
  gen/
    emit_switch.py        Swift @_cdecl declarations -> GetProcAddress cases
  probe/
    main.swift            UIApplicationMain
    AppDelegate.swift     scene-based lifecycle
    SceneDelegate.swift
    ProbeViewController.swift  MTKView host
    Bootstrap.swift       dlopen SDL3, dlsym the hook, attach the view
    GLAPI.swift           the 28 entry points the probe needs, exact types
    Probe.swift           resolve pass, triangle, FBO readback, report
    Info.plist
  build.sh                dylib + manifest + GLProbe.app
  run_probe.sh            boot/install/launch, collect report.json
  out/                    generated and built artefacts (gitignored)
~~~

## Run it

~~~sh
./harness/build.sh       # ~1-2 min: WMO dylib build, manifest, probe
./harness/run_probe.sh   # boots the first available iPhone simulator
~~~

Outputs `harness/out/report.json` and `harness/out/frame.png`.

## What it already fixed

1. **The hand-written dispatch table is gone.** `HytaleGL_GetProcAddress` had 64
   hand-typed `@convention(c)` casts. `emit_switch.py` reproduces all of them
   byte-for-byte from the Swift declarations and now emits 71 cases. A wrong cast
   there used to compile and corrupt the stack at call time.
2. **Wire-up is complete.** `glCullFace` (previously a no-op), `glFrontFace`,
   `glCheckFramebufferStatus`, `glUniform1f/1i/4f`, `glEndFrame` and
   `HytaleGL_AttachView` were added. "Implemented but not exported" is now 0.
3. **The dylib can present.** `GLContext` was constructed with `view: nil` and
   nothing could attach one; `HytaleGL_AttachView` now takes an `MTKView`.
4. **Exact reachability.** 145 declared, 65 resolvable, 80 unimplemented, 6
   extensions, 71 `@_cdecl` exports, with a `--check` mode that fails on
   drift between the manifest and `nm`.

## The open bug (stopped here)

The probe reports `fboComplete: true`, `presented: true`, and a uniform clear
colour. `glCheckFramebufferStatus` is hard-coded to return complete, so the FBO
completion is not evidence of anything. The draw is dropped inside
`GLContext.pipeline(...)`, which returns nil when
`prog.vertexLib`/`prog.fragmentLib` are missing, i.e. shader translation or
`makeLibrary` failed silently. `HUD.log` now mirrors to
`/tmp/hytalegl.log`, and the probe ships the file's tail in `report.json`
under `logTail`.

Next steps if it is ever resumed:

1. Read `logTail` for `metal compile error` / uniform reflection output.
2. Log the `pipeline(...)` guard failure with the program and target key.
3. Rebuild with the same GLSL the slice uses (`ShaderSources.instVS/FS`) to rule
   out the three-line shader.

## Notes for future work

- Build the dylib with **`-whole-module-optimization`**. Without it the
  `@_cdecl` thunks are emitted once per source file and the link fails with
  71 duplicate symbols.
- The Swift module cache must live inside the workspace
  (`-module-cache-path`); the sandbox denies the default `/var/folders` path.
- `simctl launch --console` needs a FIFO outside the sandbox; the collector reads
  the report file from the app container instead.
- `glReadPixels` only works against an FBO. The default framebuffer is present-only.

## Status

Halted 2026-10-18 with the rest of the project, at milestone 1. Milestones 2–4
(conformance probes, record/replay, CI baseline) were not started.

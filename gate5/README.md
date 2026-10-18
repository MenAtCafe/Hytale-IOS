> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# Gate 5: Hytale.app, fully wired

## Bundle

~~~text
Hytale.app/
  HytaleClient        retargeted macOS->iOS, weak imports, ad-hoc signed
  SDL3.dylib          built by us for iphonesimulator, patched:
                        - constructor preloads libHytaleGL from its own directory
                        - SDL_GL_GetProcAddress consults HytaleGL_GetProcAddress first
  libHytaleGL.dylib   C-ABI GL over Metal (64 entry points at this gate; 71 after
                      the harness rebuild)
  Assets/
  Info.plist
~~~

## Startup proof

~~~text
HytaleClient[26318] (libHytaleGL.dylib) HytaleGL loaded into process
HytaleClient[26318] (SDL3.dylib) HYTALE_SDL_MESSAGEBOX title=Hytale Launcher Required
~~~

The chain is live:

~~~text
HytaleClient -> SDL3.dylib (ours) -> dlopen libHytaleGL.dylib (ours) -> Metal
~~~

## Architectural status

Every graphics and platform subsystem below the launcher gate was validated:

1. **Client execution core:** retargeted and booting managed code on iOS (Gate 2).
2. **Dynamic linking and routing:** custom SDL3 and GL wrapper libraries
   integrated (Gate 5).
3. **API resolution:** SDL maps GL entry points into our Metal implementation:
   **64 exported at this gate**, and **65 of 145 declared functions resolvable**
   after the harness rebuild (see `harness/README.md`). The two numbers
   measure different things: one counts functions the shim defines, the other
   counts functions the client can actually reach.
4. **Pipeline rendering:** deferred, instancing, compute and MSAA verified through
   the standalone `slice/` harness.

## The verification gate: not pursued

The client halts at its host environment verification: it expects to have been
started by the official launcher with a validated account session.

That check was **not** bypassed, stubbed, or patched. Two reasons:

- It is an access-control gate on a commercial product. Circumventing it is out
  of scope, whatever the research framing.
- It would not work anyway. The check is not a local boolean; a validated session
  token is a credential. Forcing the branch leaves the state machine running on a
  corrupted credential, which fails again further in.

The legitimate alternative, asking the rights holder for an offline or
development build, was not pursued before the project stopped.

## What replaced it

Rather than the game loop, the harness drives the same `SDL3 → libHytaleGL`
chain synthetically:

- `harness/manifest/` generates the authoritative 145-function manifest from
  `gl-surface.json`, the SDK `gl3.h`, `nm` on the dylib, and the shim source.
- `harness/gen/` generates the `GetProcAddress` dispatch table from the Swift
  `@_cdecl` declarations.
- `harness/probe/` is a standalone app that resolves every name through SDL,
  draws one triangle into an FBO, reads it back and presents to the default
  framebuffer.

Result at the halt: the probe runs end to end, the FBO is complete, the default
framebuffer presents, but the triangle does not rasterize (the frame is clear
colour only). That bug was not diagnosed before the halt.

## Where it stopped

Halted 2026-10-18. Remaining work: the other 80 GL entry points, the probe
triangle bug, per-frame telemetry, the app host, assets and memory, device
bring-up. None of it is planned.

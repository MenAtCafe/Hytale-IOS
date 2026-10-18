> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# Gate 3: Hytale as a native iOS app

**Result: the game launches as a real iOS application, creates a UIKit window,
loads an iOS-built SDL3, and then deliberately refuses to start without its
launcher.**

## What was done

1. Built **SDL 3.4.18** from source for `iphonesimulator` (arm64) with CMake.
2. Packaged `HytaleClient` as an app bundle:

   ~~~text
   Hytale.app/
     HytaleClient     (retargeted, weak imports, ad-hoc signed)
     SDL3.dylib       (iOS simulator build)
     Info.plist
     Assets/
   ~~~
3. Installed and launched it with `simctl`.
4. To read the modal dialog (which does not composite into screenshots), SDL3 was
   patched to log message-box contents via `NSLog`, then rebuilt.

## What happened

UIKit came up normally: a `UIWindow` became key, the display connected, fonts
loaded. SDL3 initialized. Then the game showed this modal dialog and blocked:

~~~text
Hytale Launcher Required
Start Hytale from the Hytale Launcher.
If you no longer have it, download it again from hytale.com.
~~~

The main thread is parked inside
`SDL_ShowSimpleMessageBox -> UIKit_ShowMessageBox -> NSRunLoop`.

## What this means

| Layer | Status |
|---|---|
| Mach-O retarget macOS → iOS | works |
| .NET NativeAOT runtime on iOS | works |
| Hytale's managed code | runs |
| SDL3 iOS build | loads and runs |
| UIKit window / scene | created |
| 20 macOS-only Security symbols | weakened, not hit |
| **Launcher handshake** | **blocks startup by design** |
| OpenGL → Metal renderer | not yet exercised |

The blocker is **not technical**. It is an access-control check in the client:
the game refuses to run unless it was started by the launcher, which supplies
whatever handshake the client expects.

Bypassing that check is an access-control circumvention, and this project does
not do it. That boundary is independent of who owns the copy. **This decision is
what eventually ended the project** (2026-10-18), rather than any technical wall.

## Where the technical work stood at the halt

Everything below the launcher check was demonstrated:

- the shipping binary executes on iOS,
- the .NET runtime and exception machinery work,
- an iOS SDL3 substitutes for the macOS one,
- a UIKit window exists,
- Hytale's shaders translate to Metal (59/68) and render through a GL-shaped API,
- the GL surface is mapped: 97 direct / 41 glue / 7 unsupported.

What has never been observed is Hytale's own renderer producing a frame, because
startup stops before it.

Later work (harness milestone 1) measured the reachable surface precisely:
**65 of 145** entry points resolve through the real `SDL3 → libHytaleGL`
chain. See `harness/README.md`.

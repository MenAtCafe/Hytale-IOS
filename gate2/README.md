> **Archived: project halted on 2026-10-18.** Work stopped by the author's decision. No further changes are planned; this directory records what was measured, not a work in progress.

# Gate 2: Can HytaleClient run on iOS?

**Answer: yes. The .NET NativeAOT binary boots and executes managed code inside
the iOS simulator.**

## Method

1. `machomorph` retargeted the Mach-O from macOS to `iOS-simulator`:
   platform field, framework paths (`Versions/A/` flattened), ad-hoc signature.
2. Computed the full import surface: 529 symbols. Diffed against every symbol
   exported by the iOS Simulator SDK (278,022).
3. Only **25** imports are missing on iOS; 5 are ObjC class lookups that iOS does
   export (`NSFileManager`, `NSLocale`, `NSNumber`, `NSProcessInfo`, `NSString`).
   The real gap is **20 symbols**, all legacy macOS Security.framework APIs
   (`SecKeychain*`, `SecTransform*`, `SecTrustSettings*`, `SSLSetCertificateAuthorities`)
   plus `syslog$DARWIN_EXTSN`.
4. Retargeted with `--darwin-extsn` and `--weaken-symbol` for those 19 symbols:
   they bind NULL instead of aborting the load. The binary launches; it only
   crashes if one of those code paths is actually executed.
5. Ran it with `xcrun simctl spawn`.

## What happened

Without an assets folder:

~~~text
Failed to start Hytale:

Exception: Assets directory not found. Expected at: .../gate2/Assets
   at HytaleClient!<BaseAddress>+0x397b88
   ...
Unhandled exception. System.Exception: Assets directory not found.
~~~

That is a **managed .NET exception, with a stack trace and formatted string**:
produced by Hytale's own code running on iOS.

With an (empty) `Assets` directory, the next exception is:

~~~text
System.DllNotFoundException: Unable to load shared library 'SDL3'
dlopen(.../SDL3.dylib): incompatible platform (have 'macOS', need 'iOS-simulator')
~~~

So the game resolves `SDL3.dylib` **relative to its own executable directory**:
which is why the next experiment was an iOS-built SDL3.

## Conclusion

| Question | Answer |
|---|---|
| Does the NativeAOT runtime start on iOS? | **Yes** |
| Does Hytale's own managed code execute? | **Yes** |
| Does it throw normal .NET exceptions? | **Yes** |
| Is the missing-symbol surface large? | **No**, 20 symbols, all legacy Security APIs |
| What is the first hard wall? | **SDL3 (and next, AppKit/UIKit + OpenGL/Metal)** |

The existential risk was retired here. What remained was a porting project, not
an impossibility.

## Reproduce

~~~sh
python3 machomorph/machomorph.py "$GAME/HytaleClient" -o gate2/weak/HytaleClient \
  -p iossimulator -v 27.0 --no-libraries --darwin-extsn \
  --weaken-symbol _SecKeychainOpen ...   # 19 symbols, see run9.log
codesign -f -s - gate2/weak/HytaleClient
mkdir -p gate2/Assets
xcrun simctl spawn "$UDID" "$PWD/gate2/weak/HytaleClient"
~~~

## Where this stopped

The SDL3 and app-bundle experiments became Gates 3–5. The project was halted on
2026-10-18 at the launcher/account verification gate, which was deliberately left
alone rather than bypassed.

All local copies of the game binary and their retargeted variants were removed
from this repository. Gate 2 can be repeated with your own licensed copy; the
scripts and the recorded symbol diff (`imports.txt`, `missing.txt`,
`bin_syms.txt`) remain.

#!/usr/bin/env python3
"""
gen_manifest.py - one machine-readable truth for the GL surface.

Four sources, cross-referenced:

  declared   gl-surface.json              what the client asks SDL for
  prototypes macOS SDK OpenGL/gl3.h       C signatures (145 names)
  exported   nm -gU libHytaleGL.dylib     what the dylib can answer today
  shim       slice/app/GLShim.swift       what is implemented but not exported

Outputs:
  harness/manifest/gl.json                the manifest (5 consumers)
  harness/manifest/COVERAGE.md            human-readable matrix
  harness/out/Manifest.generated.swift    GLSurface[] for the probe

Usage:
  python3 harness/manifest/gen_manifest.py
  python3 harness/manifest/gen_manifest.py --check   # exit 1 on drift
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]

# The seven functions with no iOS/Metal equivalent, per README.
NO_EQUIVALENT = {
    "glBeginTransformFeedback",
    "glEndTransformFeedback",
    "glTransformFeedbackVaryings",
    "glTexImage2DMultisample",
    "glPolygonMode",
    "glQueryCounter",
    "glGetQueryObjectui64v",
}

PROTO_RE = re.compile(
    r"GLAPI\s+([A-Za-z_][A-Za-z0-9_\s\*]*?)\s+(?:APIENTRY\s+)?(gl[A-Za-z0-9_]+)\s*"
    r"\(([^;]*?)\)\s*(?:OPENGL_DEPRECATED\([^)]*\))?\s*;",
    re.S,
)

IDENT_RE = re.compile(r"^(.*?)([A-Za-z_][A-Za-z0-9_]*)$")


def norm_type(t: str) -> str:
    t = " ".join(t.split())
    t = re.sub(r"\s*\*\s*", "*", t)
    return t


def split_args(s: str) -> list[str]:
    out: list[str] = []
    depth = 0
    cur: list[str] = []
    for ch in s:
        if ch in "<([":
            depth += 1
        elif ch in ">)]":
            depth = max(0, depth - 1)
        if ch == "," and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur))
    return [" ".join(a.split()) for a in out if a.strip()]


def parse_args(s: str) -> list[dict]:
    args = []
    for i, a in enumerate(split_args(s)):
        if a in ("void", ""):
            continue
        m = IDENT_RE.match(a)
        if m and m.group(1).strip():
            typ, name = norm_type(m.group(1)), m.group(2)
        else:
            typ, name = norm_type(a), f"arg{i}"
        args.append({"name": name, "type": typ})
    return args


def sdk_path(explicit: str | None) -> str:
    if explicit:
        return explicit
    return subprocess.run(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def parse_headers(sdk: str) -> dict[str, dict]:
    header = Path(sdk) / "System/Library/Frameworks/OpenGL.framework/Headers/gl3.h"
    if not header.exists():
        sys.exit(f"gl3.h not found under {sdk}")
    protos: dict[str, dict] = {}
    for m in PROTO_RE.finditer(header.read_text(errors="replace")):
        ret, name, args = m.group(1), m.group(2), m.group(3)
        if name not in protos:
            protos[name] = {"ret": norm_type(ret), "args": parse_args(args)}
    return protos


def exported_symbols(dylib: Path) -> set[str]:
    if not dylib.exists():
        return set()
    out = subprocess.run(["nm", "-gU", str(dylib)], capture_output=True, text=True).stdout
    names = set()
    for line in out.splitlines():
        parts = line.split()
        if parts and parts[-1].startswith("_gl"):
            names.add(parts[-1][1:])
    return names


def shim_impls(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return set(re.findall(r"func\s+(gl[A-Za-z0-9_]+)\s*\(", path.read_text(errors="replace")))


def classify(name: str, exported: set[str], impls: set[str]) -> str:
    if name in exported:
        return "exported"
    if name in impls:
        return "wireup"
    return "missing"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sdk-path")
    ap.add_argument("--dylib", default=str(REPO / "harness/out/libHytaleGL.dylib"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--out", default=str(HERE / "gl.json"))
    args = ap.parse_args()

    if not Path(args.dylib).exists():
        sys.exit(f"dylib not found: {args.dylib}\nbuild it first: ./harness/build.sh")

    surface: dict[str, list[str]] = json.loads((REPO / "gl-surface.json").read_text())
    overrides = json.loads((HERE / "overrides.json").read_text())
    protos = parse_headers(sdk_path(args.sdk_path))
    exported = exported_symbols(Path(args.dylib))
    impls = shim_impls(REPO / "slice/app/GLShim.swift")

    functions: dict[str, dict] = {}
    unresolved: list[str] = []

    for group, names in surface.items():
        for name in names:
            proto = protos.get(name)
            source = "header"
            if proto is None and name in overrides:
                ov = overrides[name]
                proto = {
                    "ret": ov["ret"],
                    "args": [{"name": a[1], "type": a[0]} for a in ov["args"]],
                }
                source = "override"
            if proto is None:
                unresolved.append(name)
                continue
            functions[name] = {
                "group": group,
                "ret": proto["ret"],
                "args": proto["args"],
                "status": classify(name, exported, impls),
                "exported": name in exported,
                "shim_impl": name in impls,
                "no_equivalent": name in NO_EQUIVALENT,
                "source": source,
            }

    extensions: dict[str, dict] = {}
    for name, ov in overrides.items():
        if not ov.get("extension"):
            continue
        extensions[name] = {
            "group": ov.get("group", "extension"),
            "ret": ov["ret"],
            "args": [{"name": a[1], "type": a[0]} for a in ov["args"]],
            "status": classify(name, exported, impls),
            "exported": name in exported,
        }

    if unresolved:
        sys.exit("no prototype and no override for: " + ", ".join(sorted(unresolved)))

    declared = set(functions)
    summary = {
        "declared": len(declared),
        "exported": sum(1 for f in functions.values() if f["exported"]),
        "wireup": sum(1 for f in functions.values() if f["status"] == "wireup"),
        "missing": sum(1 for f in functions.values() if f["status"] == "missing"),
        "no_equivalent": sum(1 for f in functions.values() if f["no_equivalent"]),
        "extensions": len(extensions),
        "unreachable": sorted(n for n, f in functions.items() if not f["exported"]),
    }
    summary["reachable_pct"] = round(100.0 * summary["exported"] / max(1, len(declared)), 1)

    manifest = {
        "schema": 1,
        "generated": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sources": {
            "surface": "gl-surface.json",
            "prototypes": "OpenGL.framework/Headers/gl3.h",
            "dylib": str(Path(args.dylib).resolve().relative_to(REPO)
                           if Path(args.dylib).resolve().is_relative_to(REPO)
                           else Path(args.dylib)),
        },
        "summary": summary,
        "functions": dict(sorted(functions.items())),
        "extensions": dict(sorted(extensions.items())),
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=1) + "\n")

    if args.check:
        problems = []
        known_ext = {n for n, ov in overrides.items() if ov.get("extension")}
        for name in sorted(exported - declared - known_ext):
            if name.startswith("gl"):
                problems.append(f"exported but not declared: {name}")
        for name, f in functions.items():
            if f["status"] == "exported" and name not in exported:
                problems.append(f"manifest says exported, dylib disagrees: {name}")
        if problems:
            print("DRIFT:")
            for p in problems:
                print("  " + p)
            sys.exit(1)
        print(f"ok: {len(declared)} declared, {len(exported)} exported, no drift")
        return

    groups = sorted(surface)
    rows = []
    for g in groups:
        names = [n for n in surface[g] if n in functions]
        exp = sum(1 for n in names if functions[n]["exported"])
        wir = sum(1 for n in names if functions[n]["status"] == "wireup")
        mis = sum(1 for n in names if functions[n]["status"] == "missing")
        rows.append((g, len(names), exp, wir, mis))

    lines = [
        "# GL surface coverage",
        "",
        "Generated by harness/manifest/gen_manifest.py from gl-surface.json, "
        "gl3.h, nm, and GLShim.swift.",
        "",
        f"**{summary['exported']} / {summary['declared']} reachable** "
        f"({summary['reachable_pct']}%) - {summary['wireup']} implemented but not "
        f"exported, {summary['missing']} unimplemented, "
        f"{summary['extensions']} extensions.",
        "",
        "| group | declared | exported | wire-up | missing |",
        "|---|---:|---:|---:|---:|",
    ]
    for g, n, e, w, m in rows:
        lines.append(f"| {g} | {n} | {e} | {w} | {m} |")
    lines += [
        f"| **total** | **{summary['declared']}** | **{summary['exported']}** "
        f"| **{summary['wireup']}** | **{summary['missing']}** |",
        "",
        "## Wire-up (implemented in the shim, absent from the dylib ABI)",
        "",
    ]
    wireup = sorted(n for n, f in functions.items() if f["status"] == "wireup")
    lines.append(", ".join(wireup) or "_none_")
    lines += ["", "## Missing (no implementation)", ""]
    missing = sorted(n for n, f in functions.items() if f["status"] == "missing")
    for g in groups:
        names = [n for n in missing if functions[n]["group"] == g]
        if names:
            lines.append(f"- **{g}**: " + ", ".join(names))
    lines += [
        "",
        "## No iOS equivalent (tier decision required)",
        "",
        ", ".join(sorted(NO_EQUIVALENT)),
        "",
    ]
    (HERE / "COVERAGE.md").write_text("\n".join(lines))

    gen_dir = REPO / "harness/out"
    gen_dir.mkdir(parents=True, exist_ok=True)
    names = sorted(functions)
    body = ",\n    ".join(json.dumps(n) for n in names)
    (gen_dir / "Manifest.generated.swift").write_text(
        "// GENERATED by harness/manifest/gen_manifest.py - do not edit\n"
        f"// {summary['declared']} declared, {summary['exported']} exported\n\n"
        "let GLSurface: [String] = [\n    " + body + "\n]\n"
    )

    print(
        f"wrote {out.relative_to(REPO)}: {summary['declared']} declared, "
        f"{summary['exported']} exported, {summary['wireup']} wire-up, "
        f"{summary['missing']} missing"
    )


if __name__ == "__main__":
    main()

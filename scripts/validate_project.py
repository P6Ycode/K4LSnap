#!/usr/bin/env python3
"""Static repository checks that do not require Theos or an iOS SDK."""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def fail(message: str) -> None:
    ERRORS.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"cannot read {path.relative_to(ROOT)}: {exc}")
        return ""


def validate_plists() -> None:
    paths = [
        ROOT / "K4LSnap.plist",
        ROOT / "prefs" / "Resources" / "Info.plist",
        ROOT / "prefs" / "Resources" / "Root.plist",
        ROOT / "prefs" / "entry.plist",
        ROOT / "layout" / "Library" / "LaunchDaemons" / "com.p6ycode.k4lsnapd.plist",
    ]
    for path in paths:
        try:
            with path.open("rb") as handle:
                plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException) as exc:
            fail(f"invalid plist {path.relative_to(ROOT)}: {exc}")


def sources_from_makefile(path: Path) -> set[str]:
    text = read(path).replace("\\\n", " ")
    pattern = r"(?:Tweak\.xm|(?:Sources|Maintenance)/[A-Za-z0-9_+./-]+\.(?:m|mm|xm|c|cc|cpp)|main\.m)"
    return set(re.findall(pattern, text))


def validate_makefile_sources() -> None:
    top = sources_from_makefile(ROOT / "Makefile")
    if not top:
        fail("Makefile does not list any tweak source files")
    for relative in sorted(top):
        if not (ROOT / relative).is_file():
            fail(f"Makefile references missing source: {relative}")

    source_files = {
        str(path.relative_to(ROOT))
        for path in (ROOT / "Sources").glob("*")
        if path.suffix in {".m", ".mm", ".xm", ".c", ".cc", ".cpp"}
    }
    for relative in sorted(source_files - top):
        fail(f"source exists but is not in Makefile: {relative}")

    root_makefile = read(ROOT / "Makefile")
    for subproject in ("prefs", "daemon", "ctl"):
        if subproject not in root_makefile:
            fail(f"root Makefile does not include {subproject} subproject")
        makefile = ROOT / subproject / "Makefile"
        listed = sources_from_makefile(makefile)
        for source in listed:
            candidate = (makefile.parent / source).resolve()
            if not candidate.is_file():
                fail(f"{makefile.relative_to(ROOT)} references missing source: {source}")


def validate_local_imports() -> None:
    candidates = list((ROOT / "Sources").glob("*.[mM]")) + list((ROOT / "Sources").glob("*.mm")) + [ROOT / "Tweak.xm"]
    candidates += list((ROOT / "prefs").glob("*.[mM]"))
    candidates += list((ROOT / "daemon").glob("*.[mM]")) + list((ROOT / "ctl").glob("*.[mM]"))
    candidates += list((ROOT / "Maintenance").glob("*.[mM]"))
    import_pattern = re.compile(r'^\s*#import\s+"([^"]+)"', re.MULTILINE)
    for source in candidates:
        if not source.is_file():
            continue
        for imported in import_pattern.findall(read(source)):
            possible = [
                source.parent / imported,
                ROOT / "Headers" / imported,
                ROOT / "prefs" / imported,
                ROOT / "Maintenance" / imported,
            ]
            if not any(path.is_file() for path in possible):
                fail(f"{source.relative_to(ROOT)} imports missing local header {imported}")


def package_version() -> str | None:
    control = read(ROOT / "control")
    match = re.search(r"^Version:\s*(\S+)\s*$", control, re.MULTILINE)
    if not match:
        fail("control has no Version field")
        return None
    return match.group(1)


def validate_versions() -> None:
    version = package_version()
    if not version:
        return
    try:
        with (ROOT / "prefs" / "Resources" / "Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        if info.get("CFBundleShortVersionString") != version:
            fail("preference bundle version does not match control")
    except (OSError, plistlib.InvalidFileException):
        return

    root_text = read(ROOT / "prefs" / "Resources" / "Root.plist")
    if f"K4LSnap {version}" not in root_text:
        fail("Settings footer version does not match control")


def validate_maintenance_packaging() -> None:
    launchd = read(ROOT / "layout" / "Library" / "LaunchDaemons" / "com.p6ycode.k4lsnapd.plist")
    if "/var/jb/usr/libexec/k4lsnapd" not in launchd:
        fail("launchd plist does not contain the rootless daemon path template")
    postinst = read(ROOT / "layout" / "DEBIAN" / "postinst")
    prerm = read(ROOT / "layout" / "DEBIAN" / "prerm")
    for name, text in (("postinst", postinst), ("prerm", prerm)):
        if not text.startswith("#!/bin/sh"):
            fail(f"{name} has no shell shebang")
    if "before-package" not in read(ROOT / "Makefile"):
        fail("project validator is not wired into before-package")


def validate_schema_and_markers() -> None:
    vault = read(ROOT / "Sources" / "K4LVaultStore.m")
    if "VALUES(2)" not in vault:
        fail("vault schema migration does not declare version 2")

    marker_pattern = re.compile(r"\b(?:TODO|FIXME|PLACEHOLDER)\b", re.IGNORECASE)
    roots = (ROOT / "Sources", ROOT / "Headers", ROOT / "Maintenance", ROOT / "daemon", ROOT / "ctl")
    for directory in roots:
        for path in directory.glob("*"):
            if path.is_file() and marker_pattern.search(read(path)):
                fail(f"unfinished marker found in {path.relative_to(ROOT)}")


def main() -> int:
    validate_plists()
    validate_makefile_sources()
    validate_local_imports()
    validate_versions()
    validate_maintenance_packaging()
    validate_schema_and_markers()

    if ERRORS:
        print("K4LSnap project validation failed:", file=sys.stderr)
        for error in ERRORS:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("K4LSnap project validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

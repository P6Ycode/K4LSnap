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
    ]
    for path in paths:
        try:
            with path.open("rb") as handle:
                plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException) as exc:
            fail(f"invalid plist {path.relative_to(ROOT)}: {exc}")


def validate_makefile_sources() -> None:
    makefile = read(ROOT / "Makefile")
    normalized = makefile.replace("\\\n", " ")
    listed = set(re.findall(r"(?:Tweak\.xm|Sources/[A-Za-z0-9_+.-]+\.(?:m|mm|xm|c|cc|cpp))", normalized))
    if not listed:
        fail("Makefile does not list any tweak source files")
    for relative in sorted(listed):
        if not (ROOT / relative).is_file():
            fail(f"Makefile references missing source: {relative}")

    source_files = {str(path.relative_to(ROOT)) for path in (ROOT / "Sources").glob("*") if path.suffix in {".m", ".mm", ".xm", ".c", ".cc", ".cpp"}}
    unlisted = sorted(source_files - listed)
    for relative in unlisted:
        fail(f"source exists but is not in Makefile: {relative}")


def validate_local_imports() -> None:
    candidates = list((ROOT / "Sources").glob("*.[mM]")) + list((ROOT / "Sources").glob("*.mm")) + [ROOT / "Tweak.xm"]
    candidates += list((ROOT / "prefs").glob("*.[mM]"))
    import_pattern = re.compile(r'^\s*#import\s+"([^"]+)"', re.MULTILINE)
    for source in candidates:
        if not source.is_file():
            continue
        for imported in import_pattern.findall(read(source)):
            possible = [source.parent / imported, ROOT / "Headers" / imported, ROOT / "prefs" / imported]
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


def validate_schema_and_markers() -> None:
    vault = read(ROOT / "Sources" / "K4LVaultStore.m")
    if "VALUES(2)" not in vault:
        fail("vault schema migration does not declare version 2")

    marker_pattern = re.compile(r"\b(?:TODO|FIXME|PLACEHOLDER)\b", re.IGNORECASE)
    for path in list((ROOT / "Sources").glob("*")) + list((ROOT / "Headers").glob("*")):
        if path.is_file() and marker_pattern.search(read(path)):
            fail(f"unfinished marker found in {path.relative_to(ROOT)}")


def main() -> int:
    validate_plists()
    validate_makefile_sources()
    validate_local_imports()
    validate_versions()
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

#!/usr/bin/env python3
"""Static repository checks that do not require Theos or an iOS SDK."""
from __future__ import annotations
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
SOURCE_SUFFIXES = {".m", ".mm", ".xm", ".c", ".cc", ".cpp"}


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
        ROOT / "prefs/Resources/Info.plist",
        ROOT / "prefs/Resources/Root.plist",
        ROOT / "prefs/entry.plist",
        ROOT / "layout/Library/LaunchDaemons/com.p6ycode.k4lsnapd.plist",
    ]
    for path in paths:
        try:
            with path.open("rb") as handle:
                plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException) as exc:
            fail(f"invalid plist {path.relative_to(ROOT)}: {exc}")


def sources_from_makefile(path: Path) -> set[str]:
    text = read(path).replace("\\\n", " ")
    pattern = r"(?:Tweak\.xm|(?:\.\./)?(?:Sources|Maintenance|System)/[A-Za-z0-9_+./-]+\.(?:m|mm|xm|c|cc|cpp)|main\.m)"
    return set(re.findall(pattern, text))


def resolve_makefile_source(makefile: Path, source: str) -> Path:
    if source == "Tweak.xm":
        return ROOT / source
    if source.startswith("../"):
        return (makefile.parent / source).resolve()
    if source.startswith(("Sources/", "Maintenance/", "System/")):
        return ROOT / source
    return makefile.parent / source


def normalized_repo_source(source: str) -> str:
    return source.removeprefix("../")


def validate_makefile_sources() -> None:
    top = sources_from_makefile(ROOT / "Makefile")
    if not top:
        fail("Makefile does not list any tweak source files")
    for source in sorted(top):
        if not resolve_makefile_source(ROOT / "Makefile", source).is_file():
            fail(f"Makefile references missing source: {source}")

    source_files = {
        str(path.relative_to(ROOT))
        for path in (ROOT / "Sources").glob("*")
        if path.suffix in SOURCE_SUFFIXES
    }
    linked_top = {normalized_repo_source(source) for source in top}
    for relative in sorted(source_files - linked_top):
        fail(f"source exists but is not in Makefile: {relative}")

    root_makefile = read(ROOT / "Makefile")
    linked_all = set(linked_top)
    for subproject in ("prefs", "daemon", "ctl"):
        if subproject not in root_makefile:
            fail(f"root Makefile does not include {subproject} subproject")
        makefile = ROOT / subproject / "Makefile"
        listed = sources_from_makefile(makefile)
        linked_all.update(normalized_repo_source(source) for source in listed)
        for source in sorted(listed):
            if not resolve_makefile_source(makefile, source).is_file():
                fail(f"{makefile.relative_to(ROOT)} references missing source: {source}")

    system_sources = {str(path.relative_to(ROOT)) for path in (ROOT / "System").glob("*.m")}
    for relative in sorted(system_sources - linked_all):
        fail(f"system source exists but is not linked: {relative}")


def validate_local_imports() -> None:
    candidates: list[Path] = []
    for directory in ("Sources", "prefs", "daemon", "ctl", "Maintenance", "System"):
        candidates += list((ROOT / directory).glob("*.m"))
        candidates += list((ROOT / directory).glob("*.mm"))
    candidates += [ROOT / "Tweak.xm"]
    pattern = re.compile(r'^\s*#import\s+"([^"]+)"', re.MULTILINE)
    for source in candidates:
        if not source.is_file():
            continue
        for imported in pattern.findall(read(source)):
            possible = [
                source.parent / imported,
                ROOT / "Headers" / imported,
                ROOT / "prefs" / imported,
                ROOT / "Maintenance" / imported,
                ROOT / "System" / imported,
            ]
            if not any(path.is_file() for path in possible):
                fail(f"{source.relative_to(ROOT)} imports missing local header {imported}")


def package_version() -> str | None:
    match = re.search(r"^Version:\s*(\S+)\s*$", read(ROOT / "control"), re.MULTILINE)
    if not match:
        fail("control has no Version field")
        return None
    return match.group(1)


def validate_versions() -> None:
    version = package_version()
    if not version:
        return
    try:
        with (ROOT / "prefs/Resources/Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        if info.get("CFBundleShortVersionString") != version:
            fail("preference bundle version does not match control")
    except (OSError, plistlib.InvalidFileException):
        return
    if f"K4LSnap {version}" not in read(ROOT / "prefs/Resources/Root.plist"):
        fail("Settings footer version does not match control")


def validate_maintenance_packaging() -> None:
    launchd = read(ROOT / "layout/Library/LaunchDaemons/com.p6ycode.k4lsnapd.plist")
    if "/var/jb/usr/libexec/k4lsnapd" not in launchd:
        fail("launchd plist does not contain the rootless daemon path template")
    for name in ("postinst", "prerm"):
        if not read(ROOT / "layout/DEBIAN" / name).startswith("#!/bin/sh"):
            fail(f"{name} has no shell shebang")
    if "before-package" not in read(ROOT / "Makefile"):
        fail("project validator is not wired into before-package")


def validate_protocol() -> None:
    protocol = read(ROOT / "System/K4LSystemProtocol.m")
    daemon = read(ROOT / "daemon/main.m")
    for token in ("command-available", "command-result", "protocolVersion", "Commands", "Results", "Diagnostics", "Backups"):
        if token not in protocol:
            fail(f"system protocol is missing {token}")
    for command in ("discover-container", "backup-create", "backup-restore", "account-mask-snapshot"):
        if command not in daemon:
            fail(f"daemon does not implement {command}")
    masks = read(ROOT / "System/K4LAccountCategoryStore.h")
    for mask in ("0x01", "0x02", "0x04", "0x08", "0x10", "0x20", "0x40", "0x1E"):
        if mask not in masks:
            fail(f"account category mask model is missing {mask}")


def validate_schema_and_markers() -> None:
    if "VALUES(2)" not in read(ROOT / "Sources/K4LVaultStore.m"):
        fail("vault schema migration does not declare version 2")
    comment_marker = re.compile(
        r"(?im)^\s*(?://+|/\*+|\*+)\s*(?:TODO|FIXME|PLACEHOLDER)\b"
    )
    for directory in ("Sources", "Headers", "Maintenance", "System", "daemon", "ctl"):
        for path in (ROOT / directory).glob("*"):
            if path.is_file() and comment_marker.search(read(path)):
                fail(f"unfinished marker found in {path.relative_to(ROOT)}")


def main() -> int:
    validate_plists()
    validate_makefile_sources()
    validate_local_imports()
    validate_versions()
    validate_maintenance_packaging()
    validate_protocol()
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

#!/usr/bin/env python3
"""Static repository checks that do not require Theos or an iOS SDK."""
from __future__ import annotations
import plistlib,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];ERRORS:list[str]=[]
def fail(message:str)->None:ERRORS.append(message)
def read(path:Path)->str:
    try:return path.read_text(encoding="utf-8")
    except OSError as exc:fail(f"cannot read {path.relative_to(ROOT)}: {exc}");return ""
def validate_plists()->None:
    paths=[ROOT/"K4LSnap.plist",ROOT/"prefs/Resources/Info.plist",ROOT/"prefs/Resources/Root.plist",ROOT/"prefs/entry.plist",ROOT/"layout/Library/LaunchDaemons/com.p6ycode.k4lsnapd.plist"]
    for path in paths:
        try:
            with path.open("rb") as handle:plistlib.load(handle)
        except (OSError,plistlib.InvalidFileException) as exc:fail(f"invalid plist {path.relative_to(ROOT)}: {exc}")
def sources_from_makefile(path:Path)->set[str]:
    text=read(path).replace("\\\n"," ");pattern=r"(?:Tweak\.xm|(?:Sources|Maintenance|System)/[A-Za-z0-9_+./-]+\.(?:m|mm|xm|c|cc|cpp)|main\.m)";return set(re.findall(pattern,text))
def validate_makefile_sources()->None:
    top=sources_from_makefile(ROOT/"Makefile")
    if not top:fail("Makefile does not list any tweak source files")
    for relative in sorted(top):
        if not (ROOT/relative).is_file():fail(f"Makefile references missing source: {relative}")
    source_files={str(path.relative_to(ROOT)) for path in (ROOT/"Sources").glob("*") if path.suffix in {".m",".mm",".xm",".c",".cc",".cpp"}}
    for relative in sorted(source_files-top):fail(f"source exists but is not in Makefile: {relative}")
    root_makefile=read(ROOT/"Makefile")
    for subproject in ("prefs","daemon","ctl"):
        if subproject not in root_makefile:fail(f"root Makefile does not include {subproject} subproject")
        makefile=ROOT/subproject/"Makefile";listed=sources_from_makefile(makefile)
        for source in listed:
            candidate=(makefile.parent/source).resolve()
            if not candidate.is_file():fail(f"{makefile.relative_to(ROOT)} references missing source: {source}")
    system_sources={str(path.relative_to(ROOT)) for path in (ROOT/"System").glob("*.m")}
    linked=set()
    for makefile in (ROOT/"daemon/Makefile",ROOT/"ctl/Makefile",ROOT/"Makefile"):linked|=sources_from_makefile(makefile)
    for relative in sorted(system_sources-linked):fail(f"system source exists but is not linked: {relative}")
def validate_local_imports()->None:
    candidates=[]
    for directory in ("Sources","prefs","daemon","ctl","Maintenance","System"):
        candidates+=list((ROOT/directory).glob("*.m"))+list((ROOT/directory).glob("*.mm"))
    candidates+=[ROOT/"Tweak.xm"]
    pattern=re.compile(r'^\s*#import\s+"([^"]+)"',re.MULTILINE)
    for source in candidates:
        if not source.is_file():continue
        for imported in pattern.findall(read(source)):
            possible=[source.parent/imported,ROOT/"Headers"/imported,ROOT/"prefs"/imported,ROOT/"Maintenance"/imported,ROOT/"System"/imported]
            if not any(path.is_file() for path in possible):fail(f"{source.relative_to(ROOT)} imports missing local header {imported}")
def package_version()->str|None:
    match=re.search(r"^Version:\s*(\S+)\s*$",read(ROOT/"control"),re.MULTILINE)
    if not match:fail("control has no Version field");return None
    return match.group(1)
def validate_versions()->None:
    version=package_version()
    if not version:return
    try:
        with (ROOT/"prefs/Resources/Info.plist").open("rb") as handle:info=plistlib.load(handle)
        if info.get("CFBundleShortVersionString")!=version:fail("preference bundle version does not match control")
    except (OSError,plistlib.InvalidFileException):return
    if f"K4LSnap {version}" not in read(ROOT/"prefs/Resources/Root.plist"):fail("Settings footer version does not match control")
def validate_maintenance_packaging()->None:
    launchd=read(ROOT/"layout/Library/LaunchDaemons/com.p6ycode.k4lsnapd.plist")
    if "/var/jb/usr/libexec/k4lsnapd" not in launchd:fail("launchd plist does not contain the rootless daemon path template")
    for name in ("postinst","prerm"):
        if not read(ROOT/"layout/DEBIAN"/name).startswith("#!/bin/sh"):fail(f"{name} has no shell shebang")
    if "before-package" not in read(ROOT/"Makefile"):fail("project validator is not wired into before-package")
def validate_protocol()->None:
    protocol=read(ROOT/"System/K4LSystemProtocol.m");daemon=read(ROOT/"daemon/main.m")
    for token in ("command-available","command-result","protocolVersion","Commands","Results","Diagnostics","Backups"):
        if token not in protocol:fail(f"system protocol is missing {token}")
    for command in ("discover-container","backup-create","backup-restore","account-mask-snapshot"):
        if command not in daemon:fail(f"daemon does not implement {command}")
    masks=read(ROOT/"System/K4LAccountCategoryStore.h")
    for mask in ("0x01","0x02","0x04","0x08","0x10","0x20","0x40","0x1E"):
        if mask not in masks:fail(f"account category mask model is missing {mask}")
def validate_schema_and_markers()->None:
    if "VALUES(2)" not in read(ROOT/"Sources/K4LVaultStore.m"):fail("vault schema migration does not declare version 2")
    pattern=re.compile(r"\b(?:TODO|FIXME|PLACEHOLDER)\b",re.IGNORECASE)
    for directory in ("Sources","Headers","Maintenance","System","daemon","ctl"):
        for path in (ROOT/directory).glob("*"):
            if path.is_file() and pattern.search(read(path)):fail(f"unfinished marker found in {path.relative_to(ROOT)}")
def main()->int:
    validate_plists();validate_makefile_sources();validate_local_imports();validate_versions();validate_maintenance_packaging();validate_protocol();validate_schema_and_markers()
    if ERRORS:
        print("K4LSnap project validation failed:",file=sys.stderr)
        for error in ERRORS:print(f"  - {error}",file=sys.stderr)
        return 1
    print("K4LSnap project validation passed.");return 0
if __name__=="__main__":raise SystemExit(main())

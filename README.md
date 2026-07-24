# K4LSnap

K4LSnap is a Theos tweak project that implements a local Gallery Upload preparation flow, a SQLite-backed Media Vault, pending-send draft state, in-app controls, a Settings preference bundle, and a maintenance daemon with command-line tooling.

## Current working slice — 0.3.0

- Injects only into `com.toyopagroup.picaboo`
- Creates a draggable `K4L` launcher in the foreground app window
- Imports one image or video from Photos or Files
- Stages picker files before editing so provider URLs may safely expire
- Normalizes, rotates, center-crops, and resizes images
- Trims videos and exports with Highest, 1080p, 720p, or Medium presets
- Generates cached image thumbnails and video poster frames
- Stores caption, account, friend, category, duration, byte size, and thumbnail metadata
- Persists one current pending-send draft with caption and whole-story state
- Indexes vault media in a versioned SQLite database using WAL mode
- Migrates the original schema in place to schema version 2
- Searches, previews, edits, shares, and deletes vault items
- Runs `k4lsnapd` at boot for periodic maintenance
- Prunes abandoned Temp/Drafts files older than 24 hours
- Checks SQLite integrity, schema version, media files, and thumbnails
- Regenerates missing image and video thumbnails
- Writes a durable daemon status snapshot
- Exposes maintenance through `k4lsnapctl`
- Reloads preferences through Darwin notifications without holding the preferences queue

## Storage

- Preferences: `/var/mobile/Library/Preferences/com.p6ycode.k4lsnap.plist`
- Root data: `/var/mobile/Library/Application Support/K4LSnap`
- Media: `/var/mobile/Library/Application Support/K4LSnap/Media`
- Thumbnails: `/var/mobile/Library/Application Support/K4LSnap/Thumbnails`
- Picker staging: `/var/mobile/Library/Application Support/K4LSnap/Temp`
- Uncommitted processed drafts: `/var/mobile/Library/Application Support/K4LSnap/Drafts`
- Pending-send record: `/var/mobile/Library/Application Support/K4LSnap/pending-send.plist`
- Daemon status: `/var/mobile/Library/Application Support/K4LSnap/daemon-status.plist`
- Database: `/var/mobile/Library/Application Support/K4LSnap/vault.sqlite3`

User data stays under `/var/mobile` on both rootful and rootless jailbreaks. Package binaries and the launchd plist use the active jailbreak prefix.

## Build

```sh
export THEOS=/path/to/theos
make clean package
```

`before-package` runs `scripts/validate_project.py` before Theos assembles the package.

Install to a configured device:

```sh
make install
```

## Maintenance commands

```sh
k4lsnapctl health
k4lsnapctl status
k4lsnapctl ping
k4lsnapctl prune 24
k4lsnapctl repair-thumbnails
k4lsnapctl vacuum
k4lsnapctl reload
k4lsnapctl restart-app
```

`health` reports quick-check status, schema version, item count, missing media IDs, missing thumbnail IDs, and storage totals. `prune` touches only uncommitted Temp/Drafts files. `repair-thumbnails` updates the database after successfully regenerating thumbnails.

## Device validation matrix

### Bootstrap and settings

1. Install the package and verify **K4LSnap** appears in Settings.
2. Confirm `com.p6ycode.k4lsnapd` is loaded with `launchctl print system/com.p6ycode.k4lsnapd`.
3. Launch Snapchat and confirm the floating `K4L` button appears.
4. Disable and re-enable **Floating Launcher** repeatedly; the app must remain responsive.

### Image and video preparation

1. Import and process an image using rotation, square crop, and 1080 resize.
2. Verify the vault thumbnail and full preview match.
3. Import a video, trim both ends, and export with Highest and 720p.
4. Verify duration, playback start, and poster thumbnails.
5. Verify an invalid trim range produces an error without adding a vault record.

### Vault and draft integrity

1. Verify records survive app restart.
2. Search by caption, category, account, friend, `image`, and `video`.
3. Edit metadata and verify search updates immediately.
4. Delete an item and confirm both media and thumbnail files disappear.
5. Clear pending draft state and confirm vault media remains.

### Daemon and CLI

1. Run `k4lsnapctl ping`, wait briefly, then run `k4lsnapctl status`.
2. Confirm the status contains `running`, `daemonPID`, `integrity`, `schemaVersion`, and `timestamp`.
3. Put an old test file in `Temp`, run `k4lsnapctl prune 0`, and confirm only uncommitted files are removed.
4. Remove a cached thumbnail, run `k4lsnapctl repair-thumbnails`, and confirm the file and database path are restored.
5. Run `k4lsnapctl vacuum` and confirm the vault remains readable.
6. Run `k4lsnapctl reload` and confirm the launcher/vault refresh paths remain responsive.
7. Run `k4lsnapctl restart-app` while Snapchat is open and confirm it terminates cleanly.

### Packaging

1. On rootless, confirm the daemon binary is under `/var/jb/usr/libexec` and the CLI under `/var/jb/usr/bin`.
2. Confirm the launchd plist points at the prefixed daemon path.
3. Upgrade over 0.2.0 and verify existing schema-v2 media remains visible.
4. Remove the package and confirm launchd no longer reports `com.p6ycode.k4lsnapd`.
5. Confirm uninstall does not delete user vault data.

## Architecture

- `Tweak.xm` — injected bootstrap and reload observer
- `Sources/` — gallery, editor, vault, preferences, previews, and pending-send state
- `Maintenance/K4LMaintenance` — shared health, pruning, thumbnail repair, vacuum, and status engine
- `daemon/` — `k4lsnapd` launch daemon
- `ctl/` — `k4lsnapctl` command-line tool
- `prefs/` — iOS Settings preference bundle
- `layout/Library/LaunchDaemons/` — launchd definition
- `layout/DEBIAN/` — bootstrap and removal scripts
- `scripts/validate_project.py` — static package validator

The source has received a static audit in this environment. A real compile and device pass still requires Theos, an iOS SDK, and the target jailbroken device.

# K4LSnap

K4LSnap is a Theos tweak project that currently implements a local Gallery Upload preparation flow, a SQLite-backed Media Vault, pending-send draft state, in-app controls, and a Settings preference bundle.

## Current working slice — 0.2.0

- Injects only into `com.toyopagroup.picaboo`
- Creates a draggable `K4L` launcher in the foreground app window
- Imports one image or video from Photos or Files
- Stages picker files before editing so provider URLs may safely expire
- Normalizes image orientation
- Rotates images in 90-degree steps
- Center-crops images to original, square, or portrait 9:16
- Resizes images to original size, 1080 maximum dimension, or 2048 maximum dimension
- Trims videos by start and end time
- Exports video using Highest, 1080p, 720p, or Medium presets with compatibility fallback
- Generates poster-frame thumbnails for videos
- Generates cached thumbnails for processed images
- Stores caption, account, friend, category, duration, byte size, and thumbnail metadata
- Persists one current pending-send draft with caption and whole-story state
- Indexes vault media in a versioned SQLite database using WAL mode
- Migrates the original schema in place to schema version 2
- Searches caption, account, friend, category, type, and path metadata
- Previews images and videos
- Edits account, friend, category, and caption after import
- Shares and deletes vault items
- Deletes cached thumbnails when the corresponding vault item is removed
- Shows vault count, storage size, pending draft, host version, and compatibility diagnostics
- Clears pending-send state separately from uncommitted temporary files
- Exposes Gallery Upload and launcher switches in both the app and iOS Settings
- Reloads preferences through a Darwin notification without holding the preferences queue

## Storage

- Preferences: `/var/mobile/Library/Preferences/com.p6ycode.k4lsnap.plist`
- Root data: `/var/mobile/Library/Application Support/K4LSnap`
- Media: `/var/mobile/Library/Application Support/K4LSnap/Media`
- Thumbnails: `/var/mobile/Library/Application Support/K4LSnap/Thumbnails`
- Picker staging: `/var/mobile/Library/Application Support/K4LSnap/Temp`
- Uncommitted processed drafts: `/var/mobile/Library/Application Support/K4LSnap/Drafts`
- Pending-send record: `/var/mobile/Library/Application Support/K4LSnap/pending-send.plist`
- Database: `/var/mobile/Library/Application Support/K4LSnap/vault.sqlite3`

User data intentionally stays under `/var/mobile` on both rootful and rootless jailbreaks. The package itself defaults to the Theos rootless scheme and may be overridden at build time.

## Build

```sh
export THEOS=/path/to/theos
make clean package
```

Install to a configured device:

```sh
make install
```

For a rootful package, override the package scheme in your build environment.

## Device validation matrix

### Bootstrap and settings

1. Install the package and verify **K4LSnap** appears in Settings.
2. Launch Snapchat and confirm the floating `K4L` button appears.
3. Disable and re-enable **Floating Launcher** in Settings; the button should react without reinstalling.
4. Confirm the app remains responsive after repeatedly toggling the setting; this exercises Darwin reload reentrancy.

### Image preparation

1. Import a portrait image from Photos.
2. Rotate it once, choose square crop, choose 1080, add caption/account/friend/category, and save.
3. Verify the vault thumbnail has the expected orientation and crop.
4. Preview the item and verify the full stored image matches the thumbnail.
5. Edit the metadata from the preview and verify search immediately finds the new values.
6. Repeat with 9:16 and 2048 to verify both crop and resize paths.

### Video preparation

1. Import a video from Files.
2. Set a trim range that removes content from both ends.
3. Export once with Highest and once with 720p.
4. Verify both records show a duration close to the selected trim range.
5. Verify each record has a poster-frame thumbnail and plays from the trimmed beginning.
6. Enter an invalid trim range shorter than 0.1 seconds and verify a readable error appears without adding a vault record.

### Vault and draft integrity

1. Verify image and video records survive app restart.
2. Search by caption, category, account, friend, `image`, and `video`.
3. Share one item through the activity sheet.
4. Delete one item and confirm both its media file and thumbnail disappear.
5. Verify **Pending Draft** shows the most recently processed item.
6. Clear the pending draft and confirm vault media remains.
7. Clear temporary and draft files and confirm committed vault media remains.

### Migration

1. Install 0.1.0, import at least one item, then install 0.2.0 over it.
2. Confirm the old item remains visible.
3. Confirm a newly processed item stores caption, thumbnail, and duration metadata.
4. Inspect `schema_meta` and confirm the version is `2`.

## Architecture

- `Tweak.xm` — injected bootstrap and reload observer
- `K4LSystem` — paths, directories, and Darwin notifications
- `K4LPreferences` — atomic shared preference storage
- `K4LVaultStore` — schema migration, SQLite index, metadata, and managed media files
- `K4LGalleryUploadCoordinator` — Photos/Files picker and staging flow
- `K4LMediaEditorViewController` — transform, trim, metadata, and draft UI
- `K4LMediaProcessor` — image pipeline, video export, and thumbnail generation
- `K4LPendingSendStore` — durable pending-send state
- `K4LLauncher` — draggable in-app entry point
- `K4LVaultViewController` — search, thumbnails, browse, share, edit, and delete
- `K4LMediaPreviewController` — image/video preview and metadata entry point
- `K4LMetadataEditorViewController` — account/friend/category/caption editing
- `K4LSettingsViewController` — in-app settings, draft controls, and diagnostics
- `K4LSnapVersionAdapter` — host version reporting
- `prefs/` — iOS Settings preference bundle

## Next implementation slice

- Maintenance daemon for pruning abandoned drafts, database integrity checks, and thumbnail repair
- `k4lsnapctl` health, reload, prune, rebuild-thumbnails, and database-check commands
- Database backup and repair workflow
- Batch account/friend/category assignment
- Thumbnail regeneration for pre-0.2 vault items

The source has received a static audit in this environment. A real compile and device pass still requires Theos, an iOS SDK, and the target jailbroken device.

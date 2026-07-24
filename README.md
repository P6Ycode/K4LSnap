# K4LSnap

K4LSnap is a Theos tweak project that currently implements a local Gallery Upload workflow, a SQLite-backed Media Vault, in-app controls, and a Settings preference bundle.

## Current working slice

- Injects only into `com.toyopagroup.picaboo`
- Creates a draggable `K4L` launcher in the foreground app window
- Imports images and videos from Photos or Files
- Copies imported media into managed local storage
- Indexes media in a versioned SQLite database using WAL mode
- Searches and filters vault records by account, friend, category, media type, and path metadata
- Previews images and videos
- Shares and deletes vault items
- Shows vault count, storage size, host version, and compatibility diagnostics
- Exposes Gallery Upload and launcher switches in both the app and iOS Settings
- Reloads preferences through a Darwin notification

## Storage

- Preferences: `/var/mobile/Library/Preferences/com.p6ycode.k4lsnap.plist`
- Root data: `/var/mobile/Library/Application Support/K4LSnap`
- Media: `/var/mobile/Library/Application Support/K4LSnap/Media`
- Temporary files: `/var/mobile/Library/Application Support/K4LSnap/Temp`
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

## First device test

1. Install the package and verify **K4LSnap** appears in Settings.
2. Launch Snapchat and confirm the floating `K4L` button appears.
3. Disable and re-enable **Floating Launcher** in Settings; the button should react without reinstalling.
4. Import one image from Photos and one video from Files.
5. Open **Media Vault** and verify both records appear.
6. Search for `image`, `video`, or `Gallery Upload`.
7. Preview each item and confirm video playback pauses when leaving the preview.
8. Share one item through the activity sheet.
9. Delete one item and confirm both the file and database record disappear.
10. Open in-app Settings and verify vault count, byte size, host version, and compatibility status.
11. Clear temporary files and confirm imported vault media remains intact.

## Architecture

- `Tweak.xm` — injected bootstrap and reload observer
- `K4LSystem` — paths, directories, and Darwin notifications
- `K4LPreferences` — atomic shared preference storage
- `K4LVaultStore` — SQLite index and managed media files
- `K4LGalleryUploadCoordinator` — Photos/Files import flow
- `K4LLauncher` — draggable in-app entry point
- `K4LVaultViewController` — search, browse, share, and delete
- `K4LMediaPreviewController` — image and video preview
- `K4LSettingsViewController` — in-app settings and diagnostics
- `K4LSnapVersionAdapter` — host version reporting
- `prefs/` — iOS Settings preference bundle

## Next implementation slice

- Image crop, rotate, and resize pipeline
- Video trim, poster-frame generation, and export presets
- Caption and pending-send model
- Account/friend/category assignment editor
- Thumbnail cache and richer vault cells
- Maintenance daemon and command-line health tool

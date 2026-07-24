# K4LSnap

K4LSnap is a modular iOS jailbreak tweak project for reconstructing the authorized Hush feature set against a pinned Snapchat build.

## Initial scope

- Gallery Upload / Send Snap
- Screenshot interception and suppression
- Save suppression and tap-to-save policy
- Snapshot save gating and deferred writes
- Disk-write suppression and keep-deleted-content policy
- Replay suppression
- Chat, Snap, and Remix ghost-mode adapters

The project deliberately separates stable feature logic from Snapchat-version-specific selectors. Private hooks live behind `K4LSnapVersionAdapter`, so updating Snapchat does not require rewriting the policy and media pipelines.

## Build

Requires Theos and an arm64/arm64e iOS SDK.

```sh
make package
```

Set the target Snapchat version in the adapter before enabling private hooks on-device.

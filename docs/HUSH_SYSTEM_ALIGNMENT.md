# Hush system alignment — K4LSnap 0.4.0

This document maps the K4LSnap system layer to the recovered Hush daemon/account reports without inventing unresolved runtime facts.

## Implemented report-backed architecture

- Resident launch daemon with `RunAtLoad` and `KeepAlive` packaging.
- Darwin notifications used as lightweight triggers and state-change broadcasts.
- Versioned command and result envelopes stored as atomic plist files.
- SQLite-backed durable vault state using WAL mode.
- Shared preference state under `/var/mobile/Library/Preferences`.
- Durable daemon status, diagnostics history, pending-send state, container cache, and backup manifests.
- Application data-container discovery through MobileContainerManager metadata.
- Maintenance commands for health, prune, thumbnail repair, vacuum, container discovery, backup/restore, and account-mask inspection.
- Account category mask mechanics matching the static report:
  - bit `0x01`: account-specific override enabled;
  - bits `0x02`, `0x04`, `0x08`, `0x10`: global-default seed subset;
  - bits `0x20`, `0x40`: account-only refinement rows;
  - unknown localized labels remain neutral until runtime localization evidence exists.

## Intentional differences

Hush paths, Mach service names, dictionary keys, and notification names are not reused. K4LSnap uses its own `com.p6ycode.k4lsnap` namespace and versioned storage layout. Licensing/session caches and uninstall-wipe licensing signals are omitted.

## XPC boundary

The report statically proves a tiny synchronous XPC request containing one `uint64` field with value `5`, but the encrypted Mach service name, dictionary key, reply shape, and exact operation meaning remain unresolved.

K4LSnap therefore models the same architectural role with a trigger notification plus durable command/result files. An XPC doorbell adapter should be added only after runtime tracing recovers the exact service, key, reply semantics, and entitlement requirements. Guessing those values would reduce fidelity.

## Runtime evidence still required

- decrypted Hush Mach service and dictionary key;
- opcode `5` reply and side effects;
- complete Hush Darwin notification vocabulary and notify-state semantics;
- exact original database paths, schemas, and mutation queries;
- exact original command/result file paths and state transitions;
- any non-licensing network role;
- exact localized names for the six account-category rows.

## Validation targets

1. `k4lsnapctl health` completes through the daemon command channel.
2. command envelopes disappear from `Commands` after completion and corresponding replies appear in `Results`.
3. daemon diagnostics append to dated files under `Diagnostics`.
4. `k4lsnapctl container` discovers and caches the pinned host application container.
5. `backup-create`, `backup-list`, and `backup-restore` preserve the SQLite database and local state files.
6. account masks sanitize unknown bits and apply global defaults only when bit `0x01` is not set.

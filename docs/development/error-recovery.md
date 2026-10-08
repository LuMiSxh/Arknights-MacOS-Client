---
title: Error recovery
description: Stable support codes, failure presentation, guarded recovery actions, and safe reports
order: 35
audience: developers
---

# Error recovery

Failures use a typed presentation snapshot, never display text. A snapshot holds an operation ID, user-facing message, optional `SupportCode`, original operation and region, and ordered allowed recovery actions.

Every user-initiated failure opens the shared detail modal once. A launch-blocking snapshot keeps **Action required** and **Show Details** in the HUD and disables launch after dismissal. Non-blocking failures, such as a failed manual update check for an installed game or optional customization work, release the HUD on dismissal.

## Ownership

- `Shared/Support` owns the closed code registry, safe report context, bundled troubleshooting lookup, and documentation URLs.
- Configuration, installation, compatibility, Rosetta, and runtime features map their typed errors to codes and recovery actions.
- `LauncherLifecycleStore` owns the current presentation and rejects stale or duplicate updates.
- `LauncherViewModel+Recovery` dispatches selected actions to the owning feature.
- The website build checks the registry against one page per code.

> [!IMPORTANT]
> User-facing messages explain the failure. They are never identifiers and never decide the code, recovery action, retry target, or report contents.

## Recovery invariants

**Retry** repeats the recorded operation only while its failure ID is current, the owning controller is idle, and the region still matches. The model consumes the failure before it starts work, so duplicate clicks cannot start concurrent operations. A region change clears the failure, so switching back cannot revive stale work.

**Repair** is offered only for installed-file failures that a full manifest verification can help. The user must confirm it. The model then revalidates the failure ID, region, installation state, and exclusive-operation gate.

The failure modal renders the matching English page from `docs/help/errors`, bundled during packaging. **Open on Website** opens the current, shareable GitHub Pages version. **Report Problem** sends only the code, operation, region, launcher version, and coarse environment, through fields declared in the GitHub issue form. Logs stay in **Settings → Storage** for maintainer-requested follow-up, not as an initial failure action.

> [!CAUTION]
> Never place user-facing error text, paths, URLs, response bodies, log excerpts, account data, or tokens in an automatically prepared public report.

## Presentation policy

A user-initiated operation can present its failure. The required initial game configuration and a manual update check can present `VIRGA`. Optional automatic refreshes for an installed game stay log-only. Features decide this before they call the shared presenter. Unpresented failures still go to the launcher log.

A newer visible status clears the previous failure unless a caller preserves it. Cancellation returns the feature to its paused or ready state and presents no support code.

## Code taxonomy

Each domain uses its own word family. A public code never encodes severity, implementation details, or a sequence number.

| Domain         | Word family           | Scope                                              | Current codes                                    |
| -------------- | --------------------- | -------------------------------------------------- | ------------------------------------------------ |
| `service`      | Atmospheric phenomena | Remote configuration and service responses         | `VIRGA`                                          |
| `installation` | Geology               | Downloads, archives, game files, and local storage | `PEBBLE`, `GABBRO`, `BASALT`, `SCREE`            |
| `runtime`      | Marine life           | Rosetta, Wine, DXMT, and compatibility setup       | `LIMPET`, `WHELK`, `SEPIA`, `ANEMONE`, `NARWHAL` |
| `process`      | Constellations        | Started game and Wine process lifecycle            | `CRUX`                                           |

The domain names the recovery owner, not the failing API. A filesystem failure while clearing game data stays in `installation`. A launcher-owned compatibility helper stays in `runtime`.

## Publishing or changing a code

1. Choose one uppercase English word from the domain's family that the project and well-known external error systems do not use. If no domain owns the recovery path, define a new domain and family first.
2. Add it to `SupportCode` and `docs/help/errors/registry.json` with its domain.
3. Add exactly one `docs/help/errors/<lowercase-code>.md` page with matching `code` and `domain` frontmatter.
4. Map typed failures and ordered actions without inspecting message strings.
5. Add fixtures for every mapped error family, route validation, report privacy, stale actions, duplicate selection, and each affected supported region.
6. Update the changelog. Run the Swift, website, and production documentation checks.

> [!NOTE]
> Public words and routes are compatibility contracts. For a different recovery path, add a new code. Never change the meaning of a published one.

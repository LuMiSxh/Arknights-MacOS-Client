---
title: Error recovery
description: Stable support codes, failure presentation, guarded recovery actions, and safe reports
order: 35
audience: developers
---

# Error recovery

Launcher failures use a typed presentation snapshot instead of deriving behavior from localized text. A snapshot contains an operation ID, user-facing message, optional `SupportCode`, original operation and region, and an ordered set of allowed recovery actions.

Every user-initiated failure opens the shared detail modal once. A snapshot marked as launch-blocking keeps **Action required** and **Show Details** in the HUD and disables the normal launch action after dismissal. Non-blocking failures, such as a failed manual update check for an already installed game or optional customization work, release the HUD when their modal is dismissed.

## Ownership

- `Shared/Support` owns the closed public code registry, safe report context, bundled troubleshooting lookup, and documentation URLs.
- Configuration refresh, installation, compatibility, Rosetta, and runtime features map their typed errors to codes and recovery actions.
- `LauncherLifecycleStore` owns the current presentation and rejects stale or duplicate updates.
- `LauncherViewModel+Recovery` dispatches selected actions to the feature that owns the failed operation.
- The website validates the same registry against one documentation page per code during its production build.

> [!IMPORTANT]
> Localized messages explain the immediate failure. They are never identifiers and must not decide the code, recovery action, retry target, or report contents.

## Recovery invariants

**Retry** repeats the recorded operation only while its failure ID is current, the owning controller is idle, and the selected region still matches. Consuming the failure before starting work prevents duplicate clicks from creating concurrent operations. A region change clears the current failure so switching away and back cannot revive stale work.

**Repair** is offered only for installed-file failures where a full manifest verification can help. The user must confirm it, and the model revalidates the failure ID, region, installation state, and exclusive-operation gate after confirmation.

The failure modal renders the matching English Markdown page bundled from `docs/help/errors` during packaging. It keeps **Open on Website** available for the current, shareable GitHub Pages version. **Report Problem** sends only the code, operation, region, launcher version, and coarse environment through fields declared in the GitHub issue form. Logs remain available through **Settings → Storage** for maintainer-requested follow-up instead of appearing as an initial failure action.

> [!CAUTION]
> Never place localized error text, paths, URLs, response bodies, log excerpts, account data, or tokens in an automatically prepared public report.

## Presentation policy

A user-initiated operation may present its current failure. The initial game configuration is required and may therefore present `VIRGA`; a manually requested update check may do the same. Optional automatic refreshes for an already installed game stay log-only. Features decide this before calling the shared presenter, so the presentation layer does not carry an unused background-priority abstraction. Every unpresented failure still goes to the local launcher log.

Starting a newer visible status clears the previous failure unless a caller explicitly preserves it. Cancellation returns the owning feature to its normal paused or ready state without presenting a support code.

## Code taxonomy

Each domain uses its own word family. The family makes related failures recognizable without encoding severity, implementation details, or a sequence number in the public code.

| Domain         | Word family           | Scope                                              | Current codes                                    |
| -------------- | --------------------- | -------------------------------------------------- | ------------------------------------------------ |
| `service`      | Atmospheric phenomena | Remote configuration and service responses         | `VIRGA`                                          |
| `installation` | Geology               | Downloads, archives, game files, and local storage | `PEBBLE`, `GABBRO`, `BASALT`, `SCREE`            |
| `runtime`      | Marine life           | Rosetta, Wine, DXMT, and compatibility setup       | `LIMPET`, `WHELK`, `SEPIA`, `ANEMONE`, `NARWHAL` |
| `process`      | Constellations        | Started game and Wine process lifecycle            | `CRUX`                                           |

The domain describes the recovery owner rather than the lowest-level API that failed. For example, a filesystem failure while clearing game data remains in `installation`, and a launcher-owned compatibility helper remains in `runtime`.

## Publishing or changing a code

1. Choose one uppercase English word from the domain's word family that is not used by the project or a well-known external error system. Define a new domain and family first if none of the existing scopes owns the recovery path.
2. Add it to `SupportCode` and `docs/help/errors/registry.json` with its domain.
3. Add exactly one `docs/help/errors/<lowercase-code>.md` page with matching `code` and `domain` frontmatter.
4. Map typed failures and ordered actions without inspecting message strings.
5. Add fixtures for every mapped error family, route validation, report privacy, stale actions, duplicate selection, and each supported region affected by the operation.
6. Update the changelog and run the Swift, localization, website, and production documentation checks.

> [!NOTE]
> Public words and routes are compatibility contracts. Prefer adding a new code for a genuinely different recovery path over changing the meaning of a published one.

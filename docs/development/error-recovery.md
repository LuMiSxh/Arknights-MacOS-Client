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

- `Shared/Support` owns the generated `SupportCode` enum, safe report context, bundled troubleshooting lookup, and documentation URLs.
- `LauncherLifecycleStore` owns the current presentation and rejects stale or duplicate updates.
- `LauncherViewModel+Recovery` dispatches selected actions to the owning feature.
- The website build checks the generated registry against one page per code.

> [!IMPORTANT]
> User-facing messages explain the failure. They are never identifiers and never decide the code, recovery action, retry target, or report contents.

## Error types

Each feature owns one error type and maps it to a support code at its own boundary. `LauncherError` in `Core/Errors` holds cross-feature failures. `SupportCodeStabilityTests` pins support codes and messages.

## Recovery invariants

**Retry** repeats the recorded operation only while its failure ID is current, the owning controller is idle, and the region still matches. The model consumes the failure before it starts work, so duplicate clicks cannot start concurrent operations. A region change clears the failure, so switching back cannot revive stale work.

**Repair** is offered only for installed-file failures that a full manifest verification can help. The user must confirm it. The model then revalidates the failure ID, region, installation state, and exclusive-operation gate.

The failure modal renders the matching English page from `docs/help/errors`, bundled during packaging. **Open on Website** opens the current, shareable GitHub Pages version. **Report a Problem** sends only the code, operation, region, opening place, launcher version, and coarse environment, through fields declared in the GitHub issue form. Logs stay in **Settings → Storage** for maintainer-requested follow-up, not as an initial failure action.

> [!CAUTION]
> Never place user-facing error text, paths, URLs, response bodies, log excerpts, account data, or tokens in an automatically prepared public report.

## Presentation policy

A user-initiated operation can present its failure. The required initial game configuration and a manual update check can present `SV-ERR`. Optional automatic refreshes for an installed game stay log-only. Features decide this before they call the shared presenter. Unpresented failures still go to the launcher log.

A newer visible status clears the previous failure unless a caller preserves it. Cancellation returns the feature to its paused or ready state and presents no support code.

## Code catalog

`support-codes.json` at the repository root is the only hand-written source for public codes. `scripts/support_codes.py` generates these files from it:

- One help page for each active code in `docs/help/errors/`.
- `docs/help/errors/registry.json`.
- One hidden legacy page for each retired code, in `docs/help/errors/`. The page names the code or codes that replaced it.
- The `code` dropdown in `.github/ISSUE_TEMPLATE/problem-report.yml`.
- `Sources/ArknightsCore/Shared/Support/SupportCode.swift`.

Do not edit the generated files. Run `uv run --locked scripts/support_codes.py` after you change the catalog. `just check scripts` runs the same check with `--check`.

Each code has the form `XX-XXX`. The first two letters name the domain. The last three letters name the failure.

| Domain          | Prefix | Scope                                              |
| --------------- | ------ | -------------------------------------------------- |
| `service`       | `SV`   | Remote configuration and service responses         |
| `network`       | `NW`   | Network reachability and connection failures       |
| `installation`  | `IN`   | Downloads, archives, game files, and local storage |
| `files`         | `FS`   | Local file and data migration failures             |
| `runtime`       | `RT`   | Rosetta, Wine, DXMT, and compatibility setup       |
| `game`          | `GM`   | Started game and Wine process lifecycle            |
| `update`        | `UP`   | Launcher updates                                   |
| `customization` | `UI`   | Launcher appearance and app icon                   |

The domain names the recovery owner, not the failing API. A filesystem failure while clearing game data stays in `installation`. A launcher-owned compatibility helper stays in `runtime`.

## Adding or retiring a code

1. Choose a domain. If no domain owns the recovery path, add the domain to the generator first.
2. Add an entry to `support-codes.json`. Fill every field.
3. Run `uv run --locked scripts/support_codes.py`.
4. Map typed failures and ordered actions to the code in the owning feature. Do not inspect message strings.
5. Add fixtures for the mapped failures, report privacy, stale actions, duplicate selection, and each affected supported region.
6. Update the changelog. Run the Swift, website, and production documentation checks.

To retire a code, move it into the `legacy` list of its successor. Delete its entry. The generator then creates a hidden legacy page that names the successor.

> [!NOTE]
> A published code is a compatibility contract. Never reuse a retired code. A different meaning needs a new code.

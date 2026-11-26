---
title: Logging
description: Launcher and runtime log formats, levels, fields, and retention
order: 45
audience: developers
---

# Logging

The launcher writes two kinds of logs. Both live in
`~/Library/Logs/com.lumisxh.arknights-client/`.

- `launcher.log` records launcher work: startup, settings changes, installation, runtime
  selection, launches, prefix setup, and diagnostics.
- `arknights-<publisher>.log` records one publisher's game starts. Global, Japan, and Korea
  share `arknights-yostar.log`; Taiwan uses `arknights-gryphline.log`; China and China
  (Bilibili) use `arknights-hypergryph.log`. Wine appends to it. It starts with
  `Arknights Client session=… lane=… server=… runtime=… macos=…` and adds
  `Arknights Client timing stage=… elapsed=…` lines.

`LauncherLog` owns the launcher log. Its API is structured, so every line has the same shape.

## Line format

```text
<ISO8601 UTC> <LEVEL> <category> <event> key=value …
```

- The timestamp is ISO 8601 in UTC, with fractional seconds.
- The level is `DEBUG`, `INFO`, `WARN`, or `ERROR`, padded to five characters.
- The event is a static kebab-case name, such as `lane-access` or `step-failed`.
- Field keys are lowerCamelCase. Field order follows the call site.
- A value is double-quoted when it contains a space, quote, `=`, backslash, or control character.

Errors render as `error=<identifier> detail=…`. The identifier is a support code, `Type.case` for
a Swift error, or `domain#code` for an `NSError`. `logFields(for:)` in
`Sources/ArknightsCore/Core/Errors/LauncherError.swift` owns this mapping.

## Levels

| Level   | Use                                                                      |
| ------- | ------------------------------------------------------------------------ |
| `DEBUG` | Step detail and startup milestones. Written only with **Debug logging**. |
| `INFO`  | Milestones, such as startup, a settings change, or a launch request.     |
| `WARN`  | An expected, recoverable, or best-effort failure.                        |
| `ERROR` | A failure that the user sees or that stops a feature.                    |

**Debug logging** is in **Settings → Help → Troubleshooting**. It also enables Wine, graphics, and
MoltenVK detail.

## Categories

`LogCategory` in `Sources/ArknightsCore/Shared/Support/LauncherLogFields.swift` owns the list:
`app`, `refresh`, `install`, `runtime`, `prefix`, `launch`, `session`, `music`, `presence`,
`customization`, `update`, `diagnostics`, `settings`, and `storage`. Use the category of the
feature that emits the line.

## Rules

- Keep event names static and kebab-case. Put every variable value in a field.
- Do not build a message with `String(describing:)`. Name the fields instead.
- Pass an error with the `error:` argument. The line then carries a stable identifier and a detail.
- Never log credentials, tokens, query strings, or account IDs. A `URL` field drops its query string.
- Log private settings, such as paths and URLs that identify the user, as `<set>`.
- Use `log.attempt(.category, "event") { try … }` for best-effort work. It logs `WARN` on failure.
- Use `try?` only to remove an app-owned temporary file, as `CLAUDE.md` describes.

Call the API with `log.debug`, `log.info`, `log.warning`, or `log.error`:

```swift
log.info(.launch, "requested", ["session": id, "server": region.rawValue])
log.warning(.refresh, "failed", ["server": region.rawValue], error: error)
```

## Field keys

Use one name for each kind of value.

| Key                      | Value                                                         |
| ------------------------ | ------------------------------------------------------------- |
| `path`                   | An absolute local path, passed as a `URL`.                    |
| `file`                   | A file name only, such as `launcher.log`.                     |
| `url`                    | A remote URL.                                                 |
| `target`                 | A move or clone destination, only beside `source` or `path`.  |
| `elapsed`                | A `Duration`. Startup milestones use `elapsedMs`, an integer. |
| `exitStatus`             | A process exit code.                                          |
| `httpStatus`             | An HTTP status code.                                          |
| `result`                 | A Rosetta or text result.                                     |
| `detail`                 | Free-text context. Keep `failure` when it is an enum value.   |
| `reason`                 | An enum-like cause.                                           |
| `attempt`, `maxAttempts` | The retry position and the retry limit.                       |
| `bytes`                  | A byte count.                                                 |
| `files`                  | A file count.                                                 |
| `count`                  | Any other count.                                              |

## Add a value type

Conform a type to `LogValue` and return one unambiguous line value. A string-raw-value enum opts in
with `extension MyEnum: LogValue {}`. Sets render sorted, so a set logs the same way on every run.

## Retention

| Log                                   | Rotation                                                                                                                        |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `launcher.log`                        | Capped at 4 MiB. The current file moves to `launcher.previous.log`.                                                             |
| `arknights-<publisher>.log`, `unity.log` | Each game start shifts the last two non-empty sessions through `*.previous.log` and `*.previous-2.log`, so three sessions stay. |

**Save Diagnostics** includes every log above. It also includes `environment.json`, which holds the
last five presented failures.

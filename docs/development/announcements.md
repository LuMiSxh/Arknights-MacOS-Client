---
title: Announcements
description: Publishing and previewing the launcher announcements feed
order: 60
---

# Announcements

The launcher fetches project messages from [`announcements.json`](../../announcements.json) on `main` at startup and when the user enables the setting. Users can disable the checks in Settings.

Each announcement shows once per preference store. A text change does not show it again; use a new `id` for a follow-up. See [Architecture § Launcher communication](architecture/communication-and-boundaries.md#launcher-communication) for how the launcher fetches, filters, and queues announcements and Yostar's in-game notices.

Use announcements for short, time-sensitive messages. They do not replace the changelog or troubleshooting guides. Keep the body useful without the action link.

The launcher selects the first eligible entry. `just announcement set` inserts or replaces an entry at the top, so the message that must win goes first. An entry counts as seen when the user dismisses its popup, not when the feed downloads or the popup waits behind another modal. The preference store keeps the latest 100 seen IDs.

## Previewing a popup

1. Run the isolated debug simulator with `just preview`.
2. Open Settings → Developer.
3. Under **HUD and popups**, set **Popup** to **Custom Markdown** and type the message.
4. Press **Show Popup** to see it in the real popup modal.

The preview uses separate temporary paths and preferences, and its game controls intercept installation and launch actions.

## Publishing

Prepare a feed entry with:

```sh
just announcement set \
	feedback-2026-08 \
	"Help improve Arknights Client" \
	/tmp/feedback.md \
	"Open GitHub Issues" \
	https://github.com/LuMiSxh/Arknights-MacOS-Client/issues
```

The recipe takes snake-case arguments and writes camel-case JSON (`action_title` becomes `actionTitle`). `action_title` and `action_url` can be `""`. Four more optional arguments set a version range and display window: `min_version`, `max_version`, `starts_at`, and `ends_at` (ISO-8601 UTC, ending in `Z`). This example shows a message only to `0.3.0` users between two dates:

```sh
just announcement set \
	thanks-0-3-0 \
	"Thanks for using 0.3.0" \
	/tmp/thanks.md \
	"" "" \
	0.3.0 0.3.0 \
	2026-08-18T00:00:00Z 2026-08-20T08:00:00Z
```

Review `announcements.json`, commit it to `main`, and push. Removing an entry hides it from installations that have not fetched it yet:

```sh
just announcement remove feedback-2026-08
```

Publishing and removing require repository write access. GitHub can briefly cache the contents response, so changes may not reach every client immediately. The command validates the feed shape and the entry before it writes. After an edit, inspect the JSON diff, run `just check`, and test the popup in the debug simulator. The launcher reads `main` through the GitHub Contents API. No announcement-specific deployment job exists.

## Feed schema and eligibility

The feed root needs `schemaVersion: 1` and an `announcements` array of at most 20 entries. The launcher rejects a feed larger than 128 KiB. `manage_announcements.py` enforces the field rules below when it creates an entry, and the launcher repeats the safety checks before it displays one.

| Field                               | Purpose                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `id`                                | Stable lowercase identifier (`[a-z0-9][a-z0-9._-]{0,79}`) used for once-only display |
| `enabled`                           | Allows an entry to remain in the file without being presented                        |
| `title`                             | Popup title, at most 120 characters                                                  |
| `body`                              | Markdown body, at most 4,000 characters                                              |
| `actionTitle` / `actionURL`         | Optional button and HTTPS destination; set both or neither                           |
| `minimumVersion` / `maximumVersion` | Optional inclusive `X.Y.Z` launcher-version range                                    |
| `startsAt` / `endsAt`               | Optional ISO-8601 UTC window ending in `Z`; the end is exclusive                     |

An entry is eligible only when it is enabled, unseen, inside its date window, and compatible with the running `X.Y.Z` version. `manage_announcements.py` rejects invalid versions, reversed date ranges, non-HTTPS action URLs, and an action title without its URL. The launcher shows at most one new entry per check and logs a failed fetch without blocking installation or launch.

The command writes all fields, with `null` for unused optional values:

```json
{
  "id": "feedback-2026-08",
  "enabled": true,
  "title": "Help improve Arknights Client",
  "body": "Tell us what should be easier to use.",
  "actionTitle": "Open GitHub Issues",
  "actionURL": "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues",
  "minimumVersion": null,
  "maximumVersion": null,
  "startsAt": null,
  "endsAt": null
}
```

## Popup Markdown

The popup uses the launcher's native Markdown parser, not the website renderer. It supports headings, paragraphs, bullet items, tables, fenced code, dividers, inline emphasis, and the five GitHub alert markers, and ignores frontmatter. Verify content in the real popup. Advanced Markdown can appear as plain text.

> [!WARNING]
> Remote Markdown renders as text and formatting only. It cannot execute HTML, JavaScript, shell commands, or native code.

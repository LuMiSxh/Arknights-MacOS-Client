---
title: Announcements
description: Publishing and previewing the launcher announcements feed
order: 60
---

# Announcements

The launcher can fetch occasional project messages from the repository without a separate server. The feed lives in [`announcements.json`](../../announcements.json) on `main` and is fetched at startup when announcements are enabled. Enabling the setting again also starts a check; users can disable these checks in Settings.

Each announcement is shown once per local preference store. Changing its text does not show it again; use a new `id` when a follow-up message should be presented. See [Architecture § Launcher communication](architecture/communication-and-boundaries.md#launcher-communication) for exactly how announcements are fetched, filtered, and queued alongside launcher status and Yostar's own in-game notices.

Announcements are for short, time-sensitive launcher messages: a maintenance note, a request for feedback, or a link to a project resource. They are not a replacement for the changelog or the troubleshooting guides. Keep the body useful without the action link; users may have links disabled or may read the popup after its display window.

The launcher selects the first eligible entry in the array. `just announcement set` inserts or replaces an entry at the top, so put the message that should win when several entries overlap first. An entry is marked seen when its popup becomes visible, not merely when the feed is downloaded. The preference store retains the latest 100 seen IDs.

## Previewing a popup

Run the isolated debug simulator, open Settings → Developer, pick "Custom popup" from the Scenario menu, type the message as Markdown, and press Show Popup to see it rendered in the real popup modal:

```sh
just preview
```

The preview uses separate temporary paths and preferences. Its game controls intercept installation and launch actions, and the focused Scenario menu covers launcher-update state, downloads, accessibility/layout, failures, Rosetta recovery, and custom popups.

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

The `just` recipe uses snake-case argument names and writes their camel-case JSON counterparts: `action_title` becomes `actionTitle`, for example. `action_title`/`action_url` may be left empty (`""`), and four more optional positional arguments follow them for a version range and display window: `min_version`, `max_version`, `starts_at`, and `ends_at` (ISO-8601 UTC, ending in `Z`). For example, to show a message only to installed `0.3.0` users between two dates:

```sh
just announcement set \
	thanks-0-3-0 \
	"Thanks for using 0.3.0" \
	/tmp/thanks.md \
	"" "" \
	0.3.0 0.3.0 \
	2026-08-18T00:00:00Z 2026-08-20T08:00:00Z
```

Review the resulting `announcements.json`, commit it to `main`, and push. Removing an entry prevents installations that have not fetched it yet from seeing it:

```sh
just announcement remove feedback-2026-08
```

Publishing and removing announcements require repository write access. GitHub may briefly cache the contents response, so changes are not guaranteed to reach every client immediately.

The `just announcement` command validates the feed shape and the entry it writes before changing the file. After editing the feed, inspect the JSON diff, run `just check`, and test the popup with the debug simulator. Publishing means merging or committing `announcements.json` to `main`; the launcher reads that branch through the GitHub Contents API. There is no announcement-specific deployment job.

## Feed schema and eligibility

The feed root must contain `schemaVersion: 1` and an `announcements` array with no more than 20 entries. The launcher rejects a feed larger than 128 KiB. `manage_announcements.py` enforces the field rules below when creating an entry, and the launcher repeats the safety checks before displaying it.

| Field                               | Purpose                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `id`                                | Stable lowercase identifier (`[a-z0-9][a-z0-9._-]{0,79}`) used for once-only display |
| `enabled`                           | Allows an entry to remain in the file without being presented                        |
| `title`                             | Popup title, at most 120 characters                                                  |
| `body`                              | Markdown body, at most 4,000 characters                                              |
| `actionTitle` / `actionURL`         | Optional button and HTTPS destination; set both or neither                           |
| `minimumVersion` / `maximumVersion` | Optional inclusive `X.Y.Z` launcher-version range                                    |
| `startsAt` / `endsAt`               | Optional ISO-8601 UTC window ending in `Z`; the end is exclusive                     |

An entry is eligible only when it is enabled, unseen, inside its date window, and compatible with the running `X.Y.Z` version. `manage_announcements.py` rejects invalid versions, reversed date ranges, non-HTTPS action URLs, or an action title without its URL. The launcher applies the same URL, version, date, and field-length safety checks before displaying an entry. It shows at most one new entry per check and logs a failed fetch without blocking installation or launch.

The command writes all schema fields, including `null` for unused optional values. A minimal resulting entry looks like this:

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

The popup uses the launcher's small native Markdown parser, not the website renderer. It supports headings, paragraphs, bullet items, tables, fenced code, dividers, inline emphasis, and the five GitHub alert markers. Frontmatter is ignored when present. Keep announcement content simple and verify it in the real popup; advanced Markdown may be displayed as plain text.

> [!WARNING]
> Remote Markdown is rendered as text and formatting only. It cannot execute HTML, JavaScript, shell commands, or native code.

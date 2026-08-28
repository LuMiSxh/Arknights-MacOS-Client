# Announcements

The launcher can fetch occasional project messages from the repository without a separate server. The feed lives in [`announcements.json`](../announcements.json) on `main` and is read once when the launcher starts. Users can disable these checks in Settings.

Each announcement is shown once per installation. Changing its text does not show it again; use a new `id` when a follow-up message should be presented. See [Architecture § Launcher communication](architecture.md#launcher-communication) for exactly how announcements are fetched, filtered, and queued alongside launcher status and Yostar's own in-game notices.

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

`action_title`/`action_url` may be left empty (`""`), and four more optional positional arguments follow them for a version range and display window: `min_version`, `max_version`, `starts_at`, and `ends_at` (ISO-8601 UTC, ending in `Z`). For example, to show a message only to installed `0.3.0` users between two dates:

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

## Feed fields

| Field                               | Purpose                                                       |
| ----------------------------------- | ------------------------------------------------------------- |
| `id`                                | Stable lowercase identifier used for once-only display        |
| `enabled`                           | Allows an entry to remain in the file without being presented |
| `title`                             | Popup title, at most 120 characters                           |
| `body`                              | Markdown body, at most 4,000 characters                       |
| `actionTitle` / `actionURL`         | Optional button and HTTPS destination; set both or neither    |
| `minimumVersion` / `maximumVersion` | Optional inclusive launcher-version range                     |
| `startsAt` / `endsAt`               | Optional ISO-8601 UTC display window                          |

Remote Markdown is rendered as text and formatting only. It cannot execute HTML, JavaScript, shell commands, or native code.

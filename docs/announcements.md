# Announcements

The launcher can fetch occasional project messages from the repository without a separate server. The feed lives in [`announcements.json`](../announcements.json) on `main` and is read once when the launcher starts. Users can disable these checks in Settings.

Each announcement is shown once per installation. Changing its text does not show it again; use a new `id` when a follow-up message should be presented.

## Previewing a popup

Write the message as Markdown and open it in the isolated debug simulator:

```sh
just preview-popup "Help improve Arknights Client" /tmp/feedback.md
```

The preview uses separate temporary paths and preferences. Its game controls never start, update, or remove the real installation.

For an app bundle with every simulated state available in Settings, run:

```sh
just preview-app
open "dist/Arknights Client.app"
```

## Publishing

Prepare a feed entry with:

```sh
just announcement-set \
	feedback-2026-08 \
	"Help improve Arknights Client" \
	/tmp/feedback.md \
	"Open GitHub Issues" \
	https://github.com/LuMiSxh/Arknights-MacOS-Client/issues
```

Review the resulting `announcements.json`, commit it to `main`, and push. Removing an entry prevents installations that have not fetched it yet from seeing it:

```sh
just announcement-remove feedback-2026-08
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

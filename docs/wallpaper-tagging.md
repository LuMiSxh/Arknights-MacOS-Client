# Wallpaper tagging and search

The Artwork gallery fetches its wallpapers from Yostar's Global Fankit gallery API and searches them by two independent signals:

- **Title** — the title Yostar published with the wallpaper.
- **Tags** — maintainer-curated keywords (operator names, events, collabs) recorded in [`WallpaperTags.json`](../Sources/ArknightsClient/Resources/WallpaperTags.json) and bundled with the app.

Yostar's titles are often generic ("Crossing", "Medjehtiqedti Bound") and rarely name the operators or events shown, so tags exist to make those wallpapers discoverable by the terms people actually search for. Matching is case- and diacritic-insensitive throughout, and lives in `WallpaperSearch` (`Presets/Models/WallpaperSearch.swift`) so it's unit-tested independently of the gallery view.

- **Multi-word queries** are split into space-separated terms that must **all** match, in the title or the tags, not necessarily the same field — `twitter angelina` finds a wallpaper whose title mentions "Twitter" and whose tags include "angelina", rather than requiring that exact phrase to appear as one substring.
- **Tags match exactly once a term is itself a complete, known tag** (e.g. the single-letter `w` operator codename) — otherwise a short tag would get swallowed into every other tag that merely starts with it (`warfarin`, `wang`, …). An incomplete term falls back to a prefix match, so partial typing (`kr`) still finds a multi-word tag (`kristen wright`) as it's typed out.
- **Committing a tag as a pill**: typing a complete tag name followed by a space (or picking one from the autocomplete row) promotes it out of the free-text field into a removable pill shown to the left of the search box, requiring an exact match rather than diluting it with prefix/substring matching. Backspace on an empty field removes the last pill.
- The title always matches by substring, since it's prose rather than a controlled vocabulary.

The gallery also offers a type filter (Story, Commemorative, Celebration, Holiday) derived purely from each wallpaper's title via `WallpaperCategory` — it needs no manifest entry and works even for untagged wallpapers.

## How new wallpapers get tagged

Tagging is deliberately a human step: identifying which operator or event a piece of art depicts requires looking at it, and no automation in this repository guesses at that.

1. **`wallpaper-tag-scan`** (`.github/workflows/wallpaper-tag-scan.yml`, daily cron + manual `workflow_dispatch`) runs [`scripts/scan_untagged_wallpapers.py`](../scripts/scan_untagged_wallpapers.py). It fetches every page of the Global gallery API, skips wallpapers already present in `WallpaperTags.json` or already covered by an open `wallpaper-tagging` issue, and files a new issue for each remaining one so it doesn't get lost. The issue embeds the artwork and its stable `global-<id>`.
2. A maintainer tags the wallpaper by hand (see below) and commits the updated `WallpaperTags.json` in a PR whose description references the issue (e.g. `Fixes #123`), which closes it once merged — there's no bot that applies tags from an issue comment.

Tags take effect the next time the app is built from `main` with the updated manifest bundled in; they are not fetched remotely at runtime.

## Running the scan locally

```sh
uv run scripts/scan_untagged_wallpapers.py --dry-run
```

Prints each untagged, unfiled wallpaper's stable ID (`global-<id>`) and preview URL without creating any GitHub issues. Drop `--dry-run` (requires `gh` to be authenticated with issue-write access) to actually file them.

## Tagging manually

Edit [`WallpaperTags.json`](../Sources/ArknightsClient/Resources/WallpaperTags.json) by hand and commit it: each key is a stable `global-<id>` wallpaper ID (find it via `uv run scripts/scan_untagged_wallpapers.py --dry-run`), and each value is an array of lowercase tag strings.

## Manifest schema

```json
{
	"schemaVersion": 1,
	"tags": {
		"global-4431": ["amiya", "closer", "anniversary"]
	}
}
```

`schemaVersion` guards against future incompatible manifest changes; bump it alongside any breaking change to the shape above.

# Wallpaper tagging and search

The Artwork gallery fetches its wallpapers from Yostar's Global Fankit gallery API and searches them by two independent signals:

- **Title** — the title Yostar published with the wallpaper.
- **Tags** — maintainer-curated keywords (operator names, events, collabs) recorded in [`WallpaperTags.json`](../Sources/ArknightsClient/Resources/WallpaperTags.json) and bundled with the app.

Yostar's titles are often generic ("Crossing", "Medjehtiqedti Bound") and rarely name the operators or events shown, so tags exist to make those wallpapers discoverable by the terms people actually search for. Search matches a wallpaper if the query appears in its title **or** in any of its tags; matching is case-insensitive and does not require tags to be present (an untagged wallpaper still matches on title alone).

## How new wallpapers get tagged

Tagging is deliberately a human step: identifying which operator or event a piece of art depicts requires looking at it, and no automation in this repository guesses at that. Two GitHub Actions workflows carry a wallpaper from "new and untagged" to "searchable by tag":

1. **`wallpaper-tag-scan`** (`.github/workflows/wallpaper-tag-scan.yml`, weekly cron + manual `workflow_dispatch`) runs [`scripts/scan_untagged_wallpapers.py`](../scripts/scan_untagged_wallpapers.py). It fetches every page of the Global gallery API, skips wallpapers already present in `WallpaperTags.json` or already covered by an open `wallpaper-tagging` issue, and files a new issue for each remaining one. The issue embeds the artwork and documents the required reply format.
2. **`wallpaper-tag-apply`** (`.github/workflows/wallpaper-tag-apply.yml`, on `issue_comment`) runs [`scripts/apply_wallpaper_tags.py`](../scripts/apply_wallpaper_tags.py) whenever someone comments on a `wallpaper-tagging` issue. It only acts on comments from the repository owner, a member, or a collaborator (`author_association`); anyone else's reply is ignored. A qualifying reply containing a line in the form:

   ```
   tags: amiya, closer, anniversary
   ```

   is parsed into a lowercase, de-duplicated tag list, written to `WallpaperTags.json` under that wallpaper's ID, committed and pushed to `main`, and the issue is closed with a confirmation comment.

Tags take effect the next time the app is built from `main` with the updated manifest bundled in; they are not fetched remotely at runtime.

## Running the scan locally

```sh
just wallpaper-scan --dry-run
```

Prints each untagged, unfiled wallpaper's stable ID (`global-<id>`) and preview URL without creating any GitHub issues. Drop `--dry-run` (requires `gh` to be authenticated with issue-write access) to actually file them.

## Tagging manually

There is currently no CLI to add or edit tags directly — tags are only ever written by `apply_wallpaper_tags.py` reacting to a qualifying issue reply, which keeps every tag traceable to a reviewed comment. To tag a wallpaper without going through an issue, edit [`WallpaperTags.json`](../Sources/ArknightsClient/Resources/WallpaperTags.json) by hand and commit it: each key is a stable `global-<id>` wallpaper ID (find it via `just wallpaper-scan --dry-run`), and each value is an array of lowercase tag strings.

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

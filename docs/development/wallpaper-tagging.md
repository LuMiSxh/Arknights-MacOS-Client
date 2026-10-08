---
title: Wallpaper tagging and search
description: Curating searchable metadata for official wallpaper presets
order: 70
audience: developers
---

# Wallpaper tagging and search

The Artwork gallery searches Yostar's official wallpaper titles and the curated operator, faction, event, and collaboration tags in [`WallpaperTags.json`](../../Sources/ArknightsClient/Resources/WallpaperTags.json). Search is case- and diacritic-insensitive. Every term must match the title or a tag. A query that exactly names a tag matches that tag, not longer tags with the same prefix.

The gallery also groups wallpapers as Story, Commemorative, Celebration, or Holiday from their official titles. This needs no manifest entry.

## Finding untagged wallpapers

The `wallpaper-tag-scan` workflow runs monthly and on manual dispatch. It compares the Global Fankit gallery with the bundled manifest and open `wallpaper-tagging` issues, then files one issue labelled `automated` and `wallpaper-tagging` per new wallpaper. It never guesses tags or edits the manifest.

Run the scan locally without creating issues:

```sh
uv run --locked scripts/scan_untagged_wallpapers.py --dry-run
```

Add lowercase tags to the `global-<id>` entry in `WallpaperTags.json` and reference the issue in the pull request. After the merge into `main`, launchers download the updated manifest when the Artwork gallery next opens after a launch. No launcher release is needed. The bundled copy is the offline fallback, refreshed with each build.

Keep the file at this path. Released launchers fetch it from `main` by this location.

```json
{
  "schemaVersion": 1,
  "tags": {
    "global-4431": ["amiya", "closer", "anniversary"]
  }
}
```

Changing the manifest shape requires a schema-version bump and a matching decoder change.

---
title: Wallpaper tagging and search
description: Curating searchable metadata for official wallpaper presets
order: 70
audience: developers
---

# Wallpaper tagging and search

The Artwork gallery searches Yostar's official wallpaper titles and the curated operator, faction, event, and collaboration tags in [`WallpaperTags.json`](../../Sources/ArknightsCore/Resources/WallpaperTags.json). Search is case- and diacritic-insensitive. Every term must match the title or a tag. A query that exactly names a tag matches that tag, not longer tags with the same prefix.

The gallery also groups wallpapers as Story, Commemorative, Celebration, or Holiday from their official titles. This needs no manifest entry.

## Finding untagged wallpapers

The `wallpaper-tag-scan` workflow runs monthly and on manual dispatch. It compares the Global Fankit gallery with the bundled manifest and the open `wallpaper-tagging` issues. It then handles all new wallpapers of one run together:

1. It asks Gemini to suggest tags for each wallpaper. The model uses Google Search grounding to confirm operator names, factions, events, and occasions.
2. It writes the suggested tags to `WallpaperTags.json` on a new branch, `chore/wallpaper-tags-<YYYY-MM-DD>`.
3. It opens one issue labelled `automated` and `wallpaper-tagging`.
4. It opens one pull request with the same labels. Merging the pull request closes the issue.

A maintainer reviews the pull request and merges it. The pull request lists each wallpaper with its preview and two tag columns:

- **Known tags** exist in the manifest or in the Global operator list.
- **New tags (verify)** do not match a known name. Check each new tag before you merge.

A wallpaper without suggested tags stays out of the manifest. The pull request lists it under **Needs manual tags**. The issue closes when the pull request merges. The next monthly run lists the wallpaper again if it is still untagged.

Run the scan locally. Neither command writes to GitHub, to git, or to the manifest.

```sh
uv run --locked scripts/scan_untagged_wallpapers.py --dry-run
```

The `--dry-run` command prints the pull request body. It suggests tags only when `GEMINI_API_KEY` is set.

To measure suggestion quality, run the evaluation. It scores the suggested tags for the N highest-numbered wallpapers that are already tagged. It prints precision and recall. The evaluation leaves the tested entries out of the prompt vocabulary.

```sh
GEMINI_API_KEY=<key> uv run --locked scripts/scan_untagged_wallpapers.py --evaluate 10
```

To change a suggested tag, edit the `global-<id>` entry in `WallpaperTags.json` on the pull request branch, then merge. After the merge into `main`, launchers download the updated manifest when the Artwork gallery next opens after a launch. No launcher release is needed. The bundled copy is the offline fallback, refreshed with each build.

### Repository setup

A repository administrator completes these steps once.

1. Add the repository secret `GEMINI_API_KEY`.
2. Open **Settings > Actions > General**. Under **Workflow permissions**, select **Allow GitHub Actions to create and approve pull requests**.

Pull requests that the default `GITHUB_TOKEN` opens do not start other workflows. The scan therefore dispatches the CI workflow on the tagging branch after it opens the pull request. That run supplies the required check.

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

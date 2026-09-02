#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Find official wallpapers missing from the curated tag manifest and file a
GitHub issue for each one so it doesn't get lost. Tagging happens separately,
by hand; a PR updating `WallpaperTags.json` that references the issue is what
closes it.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from lib.common import PROJECT_DIR, fail, output, require_command, run, run_main
from lib.console import info, success
from lib.wallpapers import GalleryWallpaper, fetch_gallery_wallpapers, parse_image_field

# GalleryWallpaper and parse_image_field are re-exported for
# scripts/tests/test_scan_untagged_wallpapers.py, which predates lib.wallpapers.
__all__ = [
    "GalleryWallpaper",
    "fetch_gallery_wallpapers",
    "main",
    "parse_image_field",
]

TAGS_MANIFEST_PATH = (
    PROJECT_DIR / "Sources/ArknightsClient/Resources/WallpaperTags.json"
)
TAGGING_LABEL = "wallpaper-tagging"
TAGGING_LABEL_COLOR = "d4c5f9"
TAGGING_LABEL_DESCRIPTION = (
    "Needs curated search tags (see docs/development/wallpaper-tagging.md)"
)
WALLPAPER_ID_MARKER = re.compile(r"<!--\s*wallpaper-id:\s*(\S+?)\s*-->")


def load_tagged_ids(manifest_path: Path) -> set[str]:
    if not manifest_path.is_file():
        return set()
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"could not read {manifest_path}: {error}")
    tags = manifest.get("tags")
    if not isinstance(tags, dict):
        fail(f"{manifest_path} must contain a top-level 'tags' object")
    return set(tags)


def already_filed_ids() -> set[str]:
    raw = output(
        [
            "gh",
            "issue",
            "list",
            "--state",
            "open",
            "--label",
            TAGGING_LABEL,
            "--json",
            "body",
            "--limit",
            "500",
        ]
    )
    filed: set[str] = set()
    for issue in json.loads(raw or "[]"):
        match = WALLPAPER_ID_MARKER.search(issue.get("body") or "")
        if match:
            filed.add(match.group(1))
    return filed


def ensure_label_exists() -> None:
    existing = output(["gh", "label", "list", "--json", "name", "--limit", "500"])
    names = {label["name"] for label in json.loads(existing or "[]")}
    if TAGGING_LABEL in names:
        return
    run(
        [
            "gh",
            "label",
            "create",
            TAGGING_LABEL,
            "--color",
            TAGGING_LABEL_COLOR,
            "--description",
            TAGGING_LABEL_DESCRIPTION,
        ]
    )


def issue_body(wallpaper: GalleryWallpaper) -> str:
    return (
        f"<!-- wallpaper-id: {wallpaper.id} -->\n"
        f"![{wallpaper.title}]({wallpaper.image_url})\n\n"
        f"**Wallpaper ID:** `{wallpaper.id}`\n"
        f"**Title:** {wallpaper.title}\n"
        f"**Source:** {wallpaper.image_url}\n\n"
        "Tag this wallpaper by hand (operator codenames, factions, event "
        "names) in `WallpaperTags.json`, then open a PR against it that "
        f'closes this issue (e.g. "Fixes #<this issue\'s number>" in the '
        "PR description)."
    )


def file_issue(wallpaper: GalleryWallpaper) -> None:
    run(
        [
            "gh",
            "issue",
            "create",
            "--title",
            f"[Wallpaper Tagging] {wallpaper.title}",
            "--label",
            TAGGING_LABEL,
            "--body",
            issue_body(wallpaper),
        ]
    )


def find_untagged(
    wallpapers: list[GalleryWallpaper], tagged_ids: set[str], filed_ids: set[str]
) -> list[GalleryWallpaper]:
    return [
        wallpaper
        for wallpaper in wallpapers
        if wallpaper.id not in tagged_ids and wallpaper.id not in filed_ids
    ]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print untagged wallpapers without creating GitHub issues",
    )
    arguments = parser.parse_args()

    if not arguments.dry_run:
        require_command("gh")

    info("Fetching the official Fankit gallery…")
    wallpapers = fetch_gallery_wallpapers()
    tagged_ids = load_tagged_ids(TAGS_MANIFEST_PATH)
    filed_ids = set() if arguments.dry_run else already_filed_ids()
    untagged = find_untagged(wallpapers, tagged_ids, filed_ids)

    if not untagged:
        success(f"All {len(wallpapers)} wallpapers are tagged or already filed.")
        return

    info(f"Found {len(untagged)} untagged wallpaper(s) out of {len(wallpapers)}.")
    if arguments.dry_run:
        for wallpaper in untagged:
            print(f"{wallpaper.id}\t{wallpaper.title}")
        return

    ensure_label_exists()
    for wallpaper in untagged:
        file_issue(wallpaper)
        success(f"Filed an issue for {wallpaper.id} ({wallpaper.title})")


if __name__ == "__main__":
    run_main(main)

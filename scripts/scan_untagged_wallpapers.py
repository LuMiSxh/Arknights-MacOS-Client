#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Find official wallpapers missing from the curated tag manifest and file a
GitHub issue for each one so a maintainer can reply with tags in the format
this script's companion, `apply_wallpaper_tags.py`, understands.
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from lib.common import PROJECT_DIR, fail, output, require_command, run, run_main
from lib.console import info, success

GALLERY_API_URL = "https://www.arknights.global/api/resource/gallery/list"
PAGE_SIZE = 50
MAX_PAGES = 10
TAGS_MANIFEST_PATH = (
    PROJECT_DIR / "Sources/ArknightsClient/Resources/WallpaperTags.json"
)
TAGGING_LABEL = "wallpaper-tagging"
TAGGING_LABEL_COLOR = "d4c5f9"
TAGGING_LABEL_DESCRIPTION = "Needs curated search tags (see apply_wallpaper_tags.py)"
WALLPAPER_ID_MARKER = re.compile(r"<!--\s*wallpaper-id:\s*(\S+?)\s*-->")


@dataclass(frozen=True)
class GalleryWallpaper:
    id: str
    title: str
    image_url: str


def parse_image_field(value: object) -> str | None:
    """Mirrors the Swift client's tolerant decoding of image1/smallImage, which
    Yostar returns as a plain string for newer entries and a single-element
    array for older ones.
    """
    if isinstance(value, str) and value:
        return value
    if isinstance(value, list) and value and isinstance(value[0], str):
        return value[0]
    if isinstance(value, int):
        return str(value)
    return None


def fetch_gallery_wallpapers() -> list[GalleryWallpaper]:
    wallpapers: list[GalleryWallpaper] = []
    for page in range(1, MAX_PAGES + 1):
        request = urllib.request.Request(
            f"{GALLERY_API_URL}?index={page}&size={PAGE_SIZE}",
            headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        rows = (
            (payload.get("data") or {}).get("rows")
            or (payload.get("data") or {}).get("list")
            or []
        )
        if not rows:
            break
        for row in rows:
            gallery_id = row.get("id")
            image_url = parse_image_field(row.get("image1")) or parse_image_field(
                row.get("smallImage")
            )
            if gallery_id is None or not image_url:
                continue
            title = (row.get("title") or "").strip() or f"Wallpaper {gallery_id}"
            wallpapers.append(
                GalleryWallpaper(
                    id=f"global-{gallery_id}", title=title, image_url=image_url
                )
            )
        if len(rows) < PAGE_SIZE:
            break
    return wallpapers


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
        "A maintainer or the repository owner can reply with search tags for this "
        "wallpaper (operator codenames, factions, event names) using this exact format:\n\n"
        "```\n"
        "tags: tag-one, tag-two, tag-three\n"
        "```\n\n"
        "Replying with that format automatically records the tags and closes this issue."
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

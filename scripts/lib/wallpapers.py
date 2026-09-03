# SPDX-License-Identifier: MPL-2.0

"""Shared access to Yostar's Global Fankit gallery API: the source of the
wallpapers listed in `WallpaperTags.json`. Used by `scan_untagged_wallpapers.py`
to file tagging issues for anything new.
"""

from __future__ import annotations

import json
import urllib.request
from dataclasses import dataclass

GALLERY_API_URL = "https://www.arknights.global/api/resource/gallery/list"
PAGE_SIZE = 50
MAX_PAGES = 10


@dataclass(frozen=True)
class GalleryWallpaper:
    id: str
    title: str
    image_url: str
    small_image_url: str | None = None


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
            small_image_url = parse_image_field(row.get("smallImage")) or image_url
            if gallery_id is None or not image_url:
                continue
            title = (row.get("title") or "").strip() or f"Wallpaper {gallery_id}"
            wallpapers.append(
                GalleryWallpaper(
                    id=f"global-{gallery_id}",
                    title=title,
                    image_url=image_url,
                    small_image_url=small_image_url,
                )
            )
        if len(rows) < PAGE_SIZE:
            break
    return wallpapers

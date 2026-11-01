# SPDX-License-Identifier: MPL-2.0

"""Suggest search tags for official wallpapers with Gemini.

The HTTP call is isolated in `generate_content` so another provider can replace
it later. Suggestions are never written to the manifest without review: each tag
carries a `known` flag. Known tags match an operator name or an existing manifest
tag; unknown tags need a maintainer to verify them.
"""

from __future__ import annotations

import base64
import json
import os
import re
import urllib.request
from collections.abc import Iterable, Sequence
from dataclasses import dataclass

from lib.console import warning
from lib.wallpapers import GalleryWallpaper

GEMINI_MODEL = "gemini-3.5-flash"
GEMINI_ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
GEMINI_KEY_ENVIRONMENT = "GEMINI_API_KEY"
GEMINI_TIMEOUT_SECONDS = 120
CHARACTER_TABLE_URL = (
    "https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData_YoStar/"
    "main/en_US/gamedata/excel/character_table.json"
)
CHARACTER_TABLE_PREFIX = "char_"
IMAGE_TIMEOUT_SECONDS = 30
MAXIMUM_IMAGE_BYTES = 20 * 1024 * 1024
FALLBACK_IMAGE_TYPE = "image/jpeg"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
JSON_ARRAY_START = re.compile(r"\[")


class TaggingError(Exception):
    """One wallpaper could not be tagged. The run continues without it."""


@dataclass(frozen=True)
class SuggestedTag:
    name: str
    known: bool


@dataclass(frozen=True)
class WallpaperSuggestion:
    wallpaper_id: str
    tags: tuple[SuggestedTag, ...]
    error: str | None = None


def normalize_tags(values: Iterable[str]) -> list[str]:
    tags: list[str] = []
    for value in values:
        tag = value.strip().lower()
        if tag and tag not in tags:
            tags.append(tag)
    return tags


def parse_tag_array(text: str) -> list[str] | None:
    """Return the first JSON array of strings in `text`.

    Grounded responses can wrap the array in prose or a code fence, and can
    contain citation brackets such as `[1]`. Those fail the string check and are
    skipped.
    """
    decoder = json.JSONDecoder()
    for match in JSON_ARRAY_START.finditer(text):
        try:
            value, _ = decoder.raw_decode(text, match.start())
        except json.JSONDecodeError:
            continue
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            return normalize_tags(value)
    return None


def operator_names_from_table(raw: bytes) -> set[str]:
    table = json.loads(raw)
    if not isinstance(table, dict):
        raise TypeError("character table must be a JSON object")
    return {
        entry["name"].strip().lower()
        for key, entry in table.items()
        if key.startswith(CHARACTER_TABLE_PREFIX)
        and isinstance(entry, dict)
        and isinstance(entry.get("name"), str)
        and entry["name"].strip()
    }


def fetch_operator_names() -> frozenset[str]:
    """Return English operator names, or an empty set when the table is unreachable."""
    try:
        return frozenset(operator_names_from_table(download(CHARACTER_TABLE_URL)))
    except (OSError, ValueError, TypeError) as error:
        warning(
            f"Could not load operator names; labelling uses manifest tags only: {error}"
        )
        return frozenset()


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=IMAGE_TIMEOUT_SECONDS) as response:
        value = response.read(MAXIMUM_IMAGE_BYTES + 1)
    if len(value) > MAXIMUM_IMAGE_BYTES:
        raise TaggingError(f"image exceeds {MAXIMUM_IMAGE_BYTES} bytes: {url}")
    return value


def download_image(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=IMAGE_TIMEOUT_SECONDS) as response:
        content_type = response.headers.get("Content-Type", "").split(";")[0].strip()
        value = response.read(MAXIMUM_IMAGE_BYTES + 1)
    if len(value) > MAXIMUM_IMAGE_BYTES:
        raise TaggingError(f"image exceeds {MAXIMUM_IMAGE_BYTES} bytes: {url}")
    mime_type = (
        content_type if content_type.startswith("image/") else FALLBACK_IMAGE_TYPE
    )
    return value, mime_type


def build_prompt(title: str, vocabulary: Sequence[str]) -> str:
    known_tags = ", ".join(vocabulary) if vocabulary else "(none)"
    return (
        "This image is an official wallpaper from the Arknights Global Fankit "
        f'gallery. Its official title is "{title}".\n\n'
        "Identify the Arknights content in the image: operators, factions, events, "
        "collaborations, and occasions such as anniversaries. Use the title and "
        "Google Search to confirm names.\n\n"
        "Write each tag in lowercase English. Use the Global English name for "
        "operators.\n"
        f"Reuse a tag from this list when it names the same thing: {known_tags}\n\n"
        "Omit anything you are not sure about. If you are not sure about anything, "
        "return an empty array.\n\n"
        'Reply with ONLY a JSON array of strings, for example ["amiya", "closer"]. '
        "Do not add any other text."
    )


def build_gemini_request(
    api_key: str, image: bytes, mime_type: str, prompt: str
) -> urllib.request.Request:
    """Build the request. The key travels only in the header, never in the URL."""
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": base64.b64encode(image).decode("ascii"),
                        }
                    },
                    {"text": prompt},
                ],
            }
        ],
        "tools": [{"google_search": {}}],
    }
    return urllib.request.Request(
        GEMINI_ENDPOINT.format(model=GEMINI_MODEL),
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )


def generate_content(request: urllib.request.Request) -> object:
    with urllib.request.urlopen(request, timeout=GEMINI_TIMEOUT_SECONDS) as response:
        return json.load(response)


def response_text(payload: object) -> str:
    try:
        parts = payload["candidates"][0]["content"]["parts"]
        return "".join(part.get("text", "") for part in parts)
    except (KeyError, IndexError, TypeError, AttributeError) as error:
        raise TaggingError("response has an unexpected shape") from error


def known_tag_names(
    manifest_tags: Iterable[str], operator_names: Iterable[str]
) -> frozenset[str]:
    return frozenset(normalize_tags([*manifest_tags, *operator_names]))


class WallpaperTagger:
    def __init__(
        self,
        api_key: str,
        vocabulary: Sequence[str],
        known_names: frozenset[str],
    ) -> None:
        self.api_key = api_key
        self.vocabulary = list(vocabulary)
        self.known_names = known_names

    def suggest(self, wallpaper: GalleryWallpaper) -> WallpaperSuggestion:
        try:
            image, mime_type = download_image(wallpaper.image_url)
            request = build_gemini_request(
                self.api_key,
                image,
                mime_type,
                build_prompt(wallpaper.title, self.vocabulary),
            )
            names = parse_tag_array(response_text(generate_content(request)))
            if names is None:
                raise TaggingError("response has no JSON array of tags")
        except (OSError, ValueError, TaggingError) as error:
            warning(f"Could not tag {wallpaper.id}: {error}")
            return WallpaperSuggestion(wallpaper.id, (), str(error))
        tags = tuple(SuggestedTag(name, name in self.known_names) for name in names)
        return WallpaperSuggestion(wallpaper.id, tags)


def api_key_from_environment() -> str:
    return os.environ.get(GEMINI_KEY_ENVIRONMENT, "").strip()

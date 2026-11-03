# SPDX-License-Identifier: MPL-2.0

import json
import urllib.error
from unittest import mock

import lib.wallpaper_tagger as tagger
from lib.wallpapers import GalleryWallpaper

WALLPAPER = GalleryWallpaper(
    id="global-4431", title="Crossing", image_url="https://example.com/a.png"
)


def gemini_payload(text: str) -> dict:
    return {"candidates": [{"content": {"parts": [{"text": text}]}}]}


def test_array_in_prose_and_code_fence_is_normalized() -> None:
    text = (
        "The image shows Amiya [1] at an anniversary event.\n"
        '```json\n["Amiya", " CLOSER ", "amiya", ""]\n```'
    )
    assert tagger.parse_tag_array(text) == ["amiya", "closer"]


def test_response_without_string_array_is_rejected() -> None:
    assert tagger.parse_tag_array("No tags found. Citations [1, 2].") is None


def test_suggestions_are_labelled_known_or_new() -> None:
    known = tagger.known_tag_names(["amiya"], ["closer"])
    payload = gemini_payload('["amiya", "closer", "made up event"]')
    with (
        mock.patch.object(tagger, "download_image", return_value=(b"png", "image/png")),
        mock.patch.object(tagger, "generate_content", return_value=payload),
    ):
        suggestion = tagger.WallpaperTagger("key", ["amiya"], known).suggest(WALLPAPER)
    assert suggestion.error is None
    assert [(tag.name, tag.known) for tag in suggestion.tags] == [
        ("amiya", True),
        ("closer", True),
        ("made up event", False),
    ]


def test_http_error_returns_no_tags_without_raising() -> None:
    rate_limited = urllib.error.HTTPError(
        "https://generativelanguage.googleapis.com",
        429,
        "Too Many Requests",
        {},
        None,
    )
    with (
        mock.patch.object(tagger, "download_image", return_value=(b"png", "image/png")),
        mock.patch.object(tagger, "generate_content", side_effect=rate_limited),
    ):
        suggestion = tagger.WallpaperTagger("key", [], frozenset()).suggest(WALLPAPER)
    assert suggestion.tags == ()
    assert "429" in (suggestion.error or "")


def test_api_key_is_sent_only_in_the_header() -> None:
    request = tagger.build_gemini_request("secret-key", b"img", "image/png", "p")
    assert "secret-key" not in request.full_url
    assert request.get_header("X-goog-api-key") == "secret-key"


def test_request_enables_google_search_grounding() -> None:
    request = tagger.build_gemini_request("key", b"img", "image/png", "p")
    assert json.loads(request.data)["tools"] == [{"google_search": {}}]


def test_operator_names_come_only_from_character_entries() -> None:
    raw = json.dumps(
        {
            "char_002_amiya": {"name": "Amiya"},
            "char_003_kalts": {"name": "Kal'tsit"},
            "token_x": {"name": "Token"},
        }
    ).encode("utf-8")
    assert tagger.operator_names_from_table(raw) == {"amiya", "kal'tsit"}


def test_unreachable_character_table_falls_back_to_manifest_tags() -> None:
    with mock.patch.object(tagger, "download", side_effect=OSError("offline")):
        assert tagger.fetch_operator_names() == frozenset()

# SPDX-License-Identifier: MPL-2.0

import json
import sys
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parents[1]))

import lib.wallpaper_tagger as tagger
from lib.wallpapers import GalleryWallpaper

WALLPAPER = GalleryWallpaper(
    id="global-4431", title="Crossing", image_url="https://example.com/a.png"
)


def gemini_payload(text: str) -> dict:
    return {"candidates": [{"content": {"parts": [{"text": text}]}}]}


class ParseTagArrayTests(unittest.TestCase):
    def test_array_in_prose_and_code_fence_is_normalized(self) -> None:
        text = (
            "The image shows Amiya [1] at an anniversary event.\n"
            '```json\n["Amiya", " CLOSER ", "amiya", ""]\n```'
        )
        self.assertEqual(tagger.parse_tag_array(text), ["amiya", "closer"])

    def test_response_without_string_array_is_rejected(self) -> None:
        self.assertIsNone(tagger.parse_tag_array("No tags found. Citations [1, 2]."))


class SuggestTests(unittest.TestCase):
    def test_suggestions_are_labelled_known_or_new(self) -> None:
        known = tagger.known_tag_names(["amiya"], ["closer"])
        payload = gemini_payload('["amiya", "closer", "made up event"]')
        with (
            mock.patch.object(
                tagger, "download_image", return_value=(b"png", "image/png")
            ),
            mock.patch.object(tagger, "generate_content", return_value=payload),
        ):
            suggestion = tagger.WallpaperTagger("key", ["amiya"], known).suggest(
                WALLPAPER
            )
        self.assertIsNone(suggestion.error)
        self.assertEqual(
            [(tag.name, tag.known) for tag in suggestion.tags],
            [("amiya", True), ("closer", True), ("made up event", False)],
        )

    def test_http_error_returns_no_tags_without_raising(self) -> None:
        rate_limited = urllib.error.HTTPError(
            "https://generativelanguage.googleapis.com",
            429,
            "Too Many Requests",
            {},
            None,
        )
        with (
            mock.patch.object(
                tagger, "download_image", return_value=(b"png", "image/png")
            ),
            mock.patch.object(tagger, "generate_content", side_effect=rate_limited),
        ):
            suggestion = tagger.WallpaperTagger("key", [], frozenset()).suggest(
                WALLPAPER
            )
        self.assertEqual(suggestion.tags, ())
        self.assertIn("429", suggestion.error or "")


class GeminiRequestTests(unittest.TestCase):
    def test_api_key_is_sent_only_in_the_header(self) -> None:
        request = tagger.build_gemini_request("secret-key", b"img", "image/png", "p")
        self.assertNotIn("secret-key", request.full_url)
        self.assertEqual(request.get_header("X-goog-api-key"), "secret-key")

    def test_request_enables_google_search_grounding(self) -> None:
        request = tagger.build_gemini_request("key", b"img", "image/png", "p")
        self.assertEqual(json.loads(request.data)["tools"], [{"google_search": {}}])


class OperatorNamesTests(unittest.TestCase):
    def test_operator_names_come_only_from_character_entries(self) -> None:
        raw = json.dumps(
            {
                "char_002_amiya": {"name": "Amiya"},
                "char_003_kalts": {"name": "Kal'tsit"},
                "token_x": {"name": "Token"},
            }
        ).encode("utf-8")
        self.assertEqual(tagger.operator_names_from_table(raw), {"amiya", "kal'tsit"})

    def test_unreachable_character_table_falls_back_to_manifest_tags(self) -> None:
        with mock.patch.object(tagger, "download", side_effect=OSError("offline")):
            self.assertEqual(tagger.fetch_operator_names(), frozenset())


if __name__ == "__main__":
    unittest.main()

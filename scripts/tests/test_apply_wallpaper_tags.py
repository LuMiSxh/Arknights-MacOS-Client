# SPDX-License-Identifier: MPL-2.0

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import apply_wallpaper_tags as apply


class ApplyWallpaperTagsTests(unittest.TestCase):
    def test_parse_tags_line_splits_and_lowercases(self) -> None:
        self.assertEqual(
            apply.parse_tags_line("tags: Amiya, Closer, Rhodes Island"),
            ["amiya", "closer", "rhodes island"],
        )

    def test_parse_tags_line_deduplicates_preserving_order(self) -> None:
        self.assertEqual(
            apply.parse_tags_line("tags: amiya, closer, amiya"),
            ["amiya", "closer"],
        )

    def test_parse_tags_line_ignores_unrelated_text(self) -> None:
        self.assertEqual(
            apply.parse_tags_line("Thanks, looks great!"),
            None,
        )

    def test_parse_tags_line_finds_line_within_larger_comment(self) -> None:
        comment = "Nice pick!\n\ntags: amiya, closer\n\nThanks for filing this."
        self.assertEqual(apply.parse_tags_line(comment), ["amiya", "closer"])

    def test_parse_tags_line_empty_tags_is_none(self) -> None:
        self.assertIsNone(apply.parse_tags_line("tags:   ,  , "))

    def test_extract_wallpaper_id_from_marker(self) -> None:
        body = "<!-- wallpaper-id: global-4431 -->\n![title](https://example.com/a.png)"
        self.assertEqual(apply.extract_wallpaper_id(body), "global-4431")

    def test_extract_wallpaper_id_missing_marker_is_none(self) -> None:
        self.assertIsNone(apply.extract_wallpaper_id("no marker here"))

    def test_apply_tags_updates_and_sorts_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "WallpaperTags.json"
            manifest_path.write_text(
                json.dumps({"schemaVersion": 1, "tags": {"global-9": ["existing"]}}),
                encoding="utf-8",
            )
            manifest = apply.apply_tags(manifest_path, "global-1", ["amiya", "closer"])
            self.assertEqual(manifest["tags"]["global-1"], ["amiya", "closer"])
            self.assertEqual(manifest["tags"]["global-9"], ["existing"])
            saved = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(list(saved["tags"].keys()), ["global-1", "global-9"])


if __name__ == "__main__":
    unittest.main()

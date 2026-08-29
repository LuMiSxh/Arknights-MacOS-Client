# SPDX-License-Identifier: MPL-2.0

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import scan_untagged_wallpapers as scan


class ScanUntaggedWallpapersTests(unittest.TestCase):
    def test_parse_image_field_plain_string(self) -> None:
        self.assertEqual(
            scan.parse_image_field("https://example.com/a.png"),
            "https://example.com/a.png",
        )

    def test_parse_image_field_single_element_array(self) -> None:
        self.assertEqual(
            scan.parse_image_field(["https://example.com/a.png"]),
            "https://example.com/a.png",
        )

    def test_parse_image_field_empty_array_is_none(self) -> None:
        self.assertIsNone(scan.parse_image_field([]))

    def test_parse_image_field_none_is_none(self) -> None:
        self.assertIsNone(scan.parse_image_field(None))

    def test_load_tagged_ids_from_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest_path = Path(directory) / "WallpaperTags.json"
            manifest_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "tags": {"global-1": ["amiya"], "global-2": []},
                    }
                ),
                encoding="utf-8",
            )
            self.assertEqual(
                scan.load_tagged_ids(manifest_path), {"global-1", "global-2"}
            )

    def test_load_tagged_ids_missing_file_is_empty(self) -> None:
        self.assertEqual(
            scan.load_tagged_ids(Path("/nonexistent/WallpaperTags.json")), set()
        )

    def test_find_untagged_excludes_tagged_and_filed(self) -> None:
        wallpapers = [
            scan.GalleryWallpaper(id="global-1", title="A", image_url="https://a"),
            scan.GalleryWallpaper(id="global-2", title="B", image_url="https://b"),
            scan.GalleryWallpaper(id="global-3", title="C", image_url="https://c"),
        ]
        untagged = scan.find_untagged(
            wallpapers, tagged_ids={"global-1"}, filed_ids={"global-2"}
        )
        self.assertEqual([wallpaper.id for wallpaper in untagged], ["global-3"])

    def test_issue_body_contains_marker_and_format_hint(self) -> None:
        wallpaper = scan.GalleryWallpaper(
            id="global-4431", title="Crossing", image_url="https://example.com/a.png"
        )
        body = scan.issue_body(wallpaper)
        self.assertIn("<!-- wallpaper-id: global-4431 -->", body)
        self.assertIn("tags: tag-one, tag-two, tag-three", body)
        self.assertIn("https://example.com/a.png", body)


if __name__ == "__main__":
    unittest.main()

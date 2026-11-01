# SPDX-License-Identifier: MPL-2.0

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import scan_untagged_wallpapers as scan
from lib.wallpaper_tagger import SuggestedTag, WallpaperSuggestion


class ScanUntaggedWallpapersTests(unittest.TestCase):
    def test_parse_image_field_supported_shapes(self) -> None:
        for value, expected in (
            ("https://example.com/a.png", "https://example.com/a.png"),
            (["https://example.com/a.png"], "https://example.com/a.png"),
            ([], None),
            (None, None),
        ):
            with self.subTest(value=value):
                self.assertEqual(scan.parse_image_field(value), expected)

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

    def test_issue_body_has_one_marker_per_wallpaper(self) -> None:
        wallpapers = [
            scan.GalleryWallpaper(id="global-1", title="A", image_url="https://a"),
            scan.GalleryWallpaper(id="global-2", title="B", image_url="https://b"),
        ]
        body = scan.issue_body(wallpapers)
        self.assertIn("<!-- wallpaper-id: global-1 -->", body)
        self.assertIn("<!-- wallpaper-id: global-2 -->", body)
        self.assertIn("![B](https://b)", body)

    def test_filed_ids_read_every_marker_in_one_issue(self) -> None:
        body = "<!-- wallpaper-id: global-1 -->\n<!-- wallpaper-id: global-2 -->"
        self.assertEqual(
            scan.filed_ids_from_bodies([body, None]), {"global-1", "global-2"}
        )

    def test_pull_request_body_closes_issue_and_lists_tags_and_manual_wallpapers(
        self,
    ) -> None:
        tagged = scan.GalleryWallpaper(
            id="global-1", title="Crossing", image_url="https://a.png"
        )
        manual = scan.GalleryWallpaper(
            id="global-2", title="Empty", image_url="https://b"
        )
        suggestions = {
            "global-1": WallpaperSuggestion(
                "global-1",
                (
                    SuggestedTag("amiya", known=True),
                    SuggestedTag("made up event", known=False),
                ),
            )
        }
        body = scan.pull_request_body("#12", [tagged], suggestions, [manual])
        self.assertTrue(body.startswith("Closes #12\n"))
        self.assertIn(
            '| `global-1` | Crossing | <img src="https://a.png" width="240"> '
            "| `amiya` | `made up event` |",
            body,
        )
        self.assertIn("## Needs manual tags", body)
        self.assertIn("- `global-2` Empty", body)

    def test_precision_and_recall_pool_counts_over_wallpapers(self) -> None:
        precision, recall = scan.precision_and_recall(
            [({"a", "b"}, {"a", "c"}), ({"d"}, set())]
        )
        self.assertAlmostEqual(precision, 1 / 2)
        self.assertAlmostEqual(recall, 1 / 3)


if __name__ == "__main__":
    unittest.main()

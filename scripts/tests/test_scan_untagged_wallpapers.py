# SPDX-License-Identifier: MPL-2.0

import json
from pathlib import Path

import pytest
import scan_untagged_wallpapers as scan
from lib.wallpaper_tagger import SuggestedTag, WallpaperSuggestion
from lib.wallpapers import GalleryWallpaper, parse_image_field


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("https://example.com/a.png", "https://example.com/a.png"),
        (["https://example.com/a.png"], "https://example.com/a.png"),
        ([], None),
        (None, None),
    ],
)
def test_parse_image_field_supported_shapes(value: object, expected: object) -> None:
    assert parse_image_field(value) == expected


def test_find_untagged_excludes_tagged_and_filed() -> None:
    wallpapers = [
        GalleryWallpaper(id="global-1", title="A", image_url="https://a"),
        GalleryWallpaper(id="global-2", title="B", image_url="https://b"),
        GalleryWallpaper(id="global-3", title="C", image_url="https://c"),
    ]
    untagged = scan.find_untagged(
        wallpapers, tagged_ids={"global-1"}, filed_ids={"global-2"}
    )
    assert [wallpaper.id for wallpaper in untagged] == ["global-3"]


def test_suggestion_document_round_trips(tmp_path: Path) -> None:
    wallpapers = [
        GalleryWallpaper(id="global-1", title="A", image_url="https://a"),
        GalleryWallpaper(id="global-2", title="B", image_url="https://b"),
    ]
    suggestions = {
        "global-1": WallpaperSuggestion(
            "global-1",
            (
                SuggestedTag("amiya", known=True),
                SuggestedTag("made up event", known=False),
            ),
        )
    }
    path = tmp_path / "suggestions.json"
    path.write_text(
        json.dumps(scan.suggestion_document(wallpapers, suggestions)), encoding="utf-8"
    )

    read_wallpapers, read_suggestions = scan.read_suggestion_document(path)

    assert read_wallpapers == wallpapers
    assert read_suggestions["global-1"].tags == suggestions["global-1"].tags
    assert read_suggestions["global-2"].tags == ()


def test_tagging_branch_is_unique_per_run() -> None:
    first = scan.tagging_branch("2026-11-08")
    second = scan.tagging_branch("2026-11-08")
    assert first != second
    assert first.startswith("chore/wallpaper-tags-2026-11-08-")


def test_issue_body_has_one_marker_per_wallpaper() -> None:
    wallpapers = [
        GalleryWallpaper(id="global-1", title="A", image_url="https://a"),
        GalleryWallpaper(id="global-2", title="B", image_url="https://b"),
    ]
    body = scan.issue_body(wallpapers)
    assert "<!-- wallpaper-id: global-1 -->" in body
    assert "<!-- wallpaper-id: global-2 -->" in body
    assert "![B](https://b)" in body


def test_filed_ids_read_every_marker_in_one_issue() -> None:
    body = "<!-- wallpaper-id: global-1 -->\n<!-- wallpaper-id: global-2 -->"
    assert scan.filed_ids_from_bodies([body, None]) == {"global-1", "global-2"}


def test_pull_request_body_closes_issue_and_lists_tags_and_manual_wallpapers() -> None:
    tagged = GalleryWallpaper(
        id="global-1", title="Crossing", image_url="https://a.png"
    )
    manual = GalleryWallpaper(id="global-2", title="Empty", image_url="https://b")
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
    assert body.startswith("Closes #12\n")
    assert (
        '| `global-1` | Crossing | <img src="https://a.png" width="240"> '
        "| `amiya` | `made up event` |"
    ) in body
    assert "## Needs manual tags" in body
    assert "- `global-2` Empty" in body


def test_precision_and_recall_pool_counts_over_wallpapers() -> None:
    precision, recall = scan.precision_and_recall(
        [({"a", "b"}, {"a", "c"}), ({"d"}, set())]
    )
    assert precision == pytest.approx(1 / 2)
    assert recall == pytest.approx(1 / 3)

# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from release_statistics import release_downloads, render_statistics

NAME = "Arknights Client"


def release(tag: str, assets: dict[str, int], *, draft: bool = False) -> dict:
    return {
        "tag_name": tag,
        "draft": draft,
        "assets": [{"name": n, "download_count": c} for n, c in assets.items()],
    }


def test_splits_dmg_sparkle_and_recipe_without_counting_other_assets() -> None:
    pages = [
        [
            release(
                "v0.2.0",
                {
                    "Arknights.Client.dmg": 12,
                    "Arknights.Client.zip": 9,
                    "Arknights.Client.tar.xz": 2,
                    "Arknights.Client42-41.delta": 6,
                    "Other42-41.delta": 70,
                    "Other.dmg": 1,
                    "Other 0.2.0.zip": 400,
                    "Runtime-Build-Recipe.tar.gz": 4,
                    "SHA256SUMS": 3,
                },
            ),
            release("v0.3.0", {"Arknights.Client.dmg": 99}, draft=True),
        ]
    ]

    assert release_downloads(pages, display_name=NAME) == [("0.2.0", 12, 17, 4)]


def test_counts_legacy_versioned_sparkle_asset() -> None:
    pages = [[release("v0.1.0", {"Arknights.Client.0.1.0.zip": 5})]]

    assert release_downloads(pages, display_name=NAME) == [("0.1.0", 0, 5, 0)]


def test_renders_rows_and_totals() -> None:
    output = render_statistics([("0.2.0", 10, 20, 1), ("0.1.0", 30, 5, 0)])

    assert "0.2.0" in output
    assert "Total app deliveries: 65" in output
    assert "Total DMG/manual package downloads: 40" in output
    assert "Total Sparkle update downloads: 25" in output
    assert "Total recipe downloads: 1" in output
    assert render_statistics([]) == "No published releases found."

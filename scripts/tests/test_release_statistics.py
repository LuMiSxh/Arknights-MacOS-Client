# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from datetime import UTC, datetime

from release_statistics import release_downloads, render_statistics


def test_counts_dmg_and_recipe_assets_separately() -> None:
    payload = [
        [
            {
                "tag_name": "v0.2.0",
                "published_at": "2026-08-16T10:00:00Z",
                "draft": False,
                "assets": [
                    {"name": "Arknights.Client.dmg", "download_count": 12},
                    {"name": "Runtime-Build-Recipe.tar.gz", "download_count": 4},
                    {"name": "SHA256SUMS", "download_count": 3},
                ],
            },
            {
                "tag_name": "v0.3.0",
                "published_at": "2026-08-17T10:00:00Z",
                "draft": True,
                "assets": [{"name": "Arknights.Client.dmg", "download_count": 99}],
            },
        ]
    ]

    releases = release_downloads(payload)

    assert len(releases) == 1
    assert releases[0].version == "0.2.0"
    assert releases[0].dmg_downloads == 12
    assert releases[0].recipe_downloads == 4


def test_renders_totals_rates_and_latest_share() -> None:
    releases = release_downloads(
        [
            [
                {
                    "tag_name": "v0.1.0",
                    "published_at": "2026-08-14T12:00:00Z",
                    "draft": False,
                    "assets": [{"name": "old.dmg", "download_count": 30}],
                },
                {
                    "tag_name": "v0.2.0",
                    "published_at": "2026-08-16T12:00:00Z",
                    "draft": False,
                    "assets": [{"name": "new.dmg", "download_count": 10}],
                },
            ]
        ]
    )

    output = render_statistics(releases, datetime(2026, 8, 17, 12, tzinfo=UTC))

    assert "Total DMG downloads: 40" in output
    assert "Total recipe downloads: 0" in output
    assert "Latest-version share (0.2.0 vs 0.1.0): 25.0%" in output
    assert "GitHub counts asset downloads" in output

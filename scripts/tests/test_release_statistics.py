# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import unittest
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from release_statistics import release_downloads, render_statistics


class ReleaseStatisticsTests(unittest.TestCase):
    def test_counts_only_published_dmg_assets(self) -> None:
        payload = [
            [
                {
                    "tag_name": "v0.2.0",
                    "published_at": "2026-08-16T10:00:00Z",
                    "draft": False,
                    "assets": [
                        {"name": "Arknights.Client.dmg", "download_count": 12},
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

        self.assertEqual(len(releases), 1)
        self.assertEqual(releases[0].version, "0.2.0")
        self.assertEqual(releases[0].downloads, 12)

    def test_renders_totals_rates_and_latest_share(self) -> None:
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

        self.assertIn("Total DMG downloads: 40", output)
        self.assertIn("Latest-version share (0.2.0 vs 0.1.0): 25.0%", output)
        self.assertIn("GitHub counts asset downloads", output)


if __name__ == "__main__":
    unittest.main()

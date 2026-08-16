# SPDX-License-Identifier: MPL-2.0

import argparse
import json
import tempfile
import unittest
from pathlib import Path

import manage_announcements


class ManageAnnouncementsTests(unittest.TestCase):
    def test_set_and_remove_announcement(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            feed = root / "announcements.json"
            body = root / "message.md"
            feed.write_text(
                '{"schemaVersion":1,"announcements":[]}\n', encoding="utf-8"
            )
            body.write_text("**Share** your feedback.", encoding="utf-8")
            previous = manage_announcements.FEED_PATH
            manage_announcements.FEED_PATH = feed
            try:
                manage_announcements.set_announcement(
                    argparse.Namespace(
                        id="feedback-2026-08",
                        title="Help improve the launcher",
                        body_file=str(body),
                        action_title="Open Issues",
                        action_url="https://github.com/example/issues",
                    )
                )
                saved = json.loads(feed.read_text(encoding="utf-8"))
                self.assertEqual(
                    saved["announcements"][0]["body"], "**Share** your feedback."
                )

                manage_announcements.remove_announcement(
                    argparse.Namespace(id="feedback-2026-08")
                )
                saved = json.loads(feed.read_text(encoding="utf-8"))
                self.assertEqual(saved["announcements"], [])
            finally:
                manage_announcements.FEED_PATH = previous


if __name__ == "__main__":
    unittest.main()

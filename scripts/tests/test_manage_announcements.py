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
                        min_version="",
                        max_version="",
                        starts_at="",
                        ends_at="",
                    )
                )
                saved = json.loads(feed.read_text(encoding="utf-8"))
                self.assertEqual(
                    saved["announcements"][0]["body"], "**Share** your feedback."
                )
                self.assertIsNone(saved["announcements"][0]["minimumVersion"])
                self.assertIsNone(saved["announcements"][0]["startsAt"])

                manage_announcements.remove_announcement(
                    argparse.Namespace(id="feedback-2026-08")
                )
                saved = json.loads(feed.read_text(encoding="utf-8"))
                self.assertEqual(saved["announcements"], [])
            finally:
                manage_announcements.FEED_PATH = previous

    def test_set_announcement_with_version_and_date_window(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            feed = root / "announcements.json"
            body = root / "message.md"
            feed.write_text(
                '{"schemaVersion":1,"announcements":[]}\n', encoding="utf-8"
            )
            body.write_text("Thanks for testing 0.3.0!", encoding="utf-8")
            previous = manage_announcements.FEED_PATH
            manage_announcements.FEED_PATH = feed
            try:
                manage_announcements.set_announcement(
                    argparse.Namespace(
                        id="thanks-0-3-0",
                        title="Thanks for using 0.3.0",
                        body_file=str(body),
                        action_title="",
                        action_url="",
                        min_version="0.3.0",
                        max_version="0.3.0",
                        starts_at="2026-08-18T00:00:00Z",
                        ends_at="2026-08-20T08:00:00Z",
                    )
                )
                saved = json.loads(feed.read_text(encoding="utf-8"))["announcements"][0]
                self.assertEqual(saved["minimumVersion"], "0.3.0")
                self.assertEqual(saved["maximumVersion"], "0.3.0")
                self.assertEqual(saved["startsAt"], "2026-08-18T00:00:00Z")
                self.assertEqual(saved["endsAt"], "2026-08-20T08:00:00Z")
            finally:
                manage_announcements.FEED_PATH = previous

    def test_rejects_starts_at_after_ends_at(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            feed = root / "announcements.json"
            body = root / "message.md"
            feed.write_text(
                '{"schemaVersion":1,"announcements":[]}\n', encoding="utf-8"
            )
            body.write_text("Body.", encoding="utf-8")
            previous = manage_announcements.FEED_PATH
            manage_announcements.FEED_PATH = feed
            try:
                with self.assertRaises(RuntimeError):
                    manage_announcements.set_announcement(
                        argparse.Namespace(
                            id="bad-window",
                            title="Bad window",
                            body_file=str(body),
                            action_title="",
                            action_url="",
                            min_version="",
                            max_version="",
                            starts_at="2026-08-20T08:00:00Z",
                            ends_at="2026-08-18T00:00:00Z",
                        )
                    )
            finally:
                manage_announcements.FEED_PATH = previous


if __name__ == "__main__":
    unittest.main()

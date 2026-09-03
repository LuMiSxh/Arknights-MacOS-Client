# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import argparse
import json
from pathlib import Path

import manage_announcements
import pytest


@pytest.fixture
def announcement_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, Path]:
    feed = tmp_path / "announcements.json"
    body = tmp_path / "message.md"
    feed.write_text('{"schemaVersion":1,"announcements":[]}\n', encoding="utf-8")
    monkeypatch.setattr(manage_announcements, "FEED_PATH", feed)
    return feed, body


def announcement_arguments(body: Path, **overrides: str) -> argparse.Namespace:
    values = {
        "id": "feedback-2026-08",
        "title": "Help improve the launcher",
        "body_file": str(body),
        "action_title": "",
        "action_url": "",
        "min_version": "",
        "max_version": "",
        "starts_at": "",
        "ends_at": "",
    }
    values.update(overrides)
    return argparse.Namespace(**values)


def test_set_and_remove_announcement(announcement_files: tuple[Path, Path]) -> None:
    feed, body = announcement_files
    body.write_text("**Share** your feedback.", encoding="utf-8")

    manage_announcements.set_announcement(
        announcement_arguments(
            body,
            action_title="Open Issues",
            action_url="https://github.com/example/issues",
        )
    )
    saved = json.loads(feed.read_text(encoding="utf-8"))
    assert saved["announcements"][0]["body"] == "**Share** your feedback."
    assert saved["announcements"][0]["minimumVersion"] is None
    assert saved["announcements"][0]["startsAt"] is None

    manage_announcements.remove_announcement(argparse.Namespace(id="feedback-2026-08"))
    saved = json.loads(feed.read_text(encoding="utf-8"))
    assert saved["announcements"] == []


def test_set_announcement_with_version_and_date_window(
    announcement_files: tuple[Path, Path],
) -> None:
    feed, body = announcement_files
    body.write_text("Thanks for testing 0.3.0!", encoding="utf-8")

    manage_announcements.set_announcement(
        announcement_arguments(
            body,
            id="thanks-0-3-0",
            title="Thanks for using 0.3.0",
            min_version="0.3.0",
            max_version="0.3.0",
            starts_at="2026-08-18T00:00:00Z",
            ends_at="2026-08-20T08:00:00Z",
        )
    )
    saved = json.loads(feed.read_text(encoding="utf-8"))["announcements"][0]
    assert saved["minimumVersion"] == "0.3.0"
    assert saved["maximumVersion"] == "0.3.0"
    assert saved["startsAt"] == "2026-08-18T00:00:00Z"
    assert saved["endsAt"] == "2026-08-20T08:00:00Z"


def test_rejects_starts_at_after_ends_at(
    announcement_files: tuple[Path, Path],
) -> None:
    _, body = announcement_files
    body.write_text("Body.", encoding="utf-8")

    with pytest.raises(RuntimeError):
        manage_announcements.set_announcement(
            announcement_arguments(
                body,
                id="bad-window",
                title="Bad window",
                starts_at="2026-08-20T08:00:00Z",
                ends_at="2026-08-18T00:00:00Z",
            )
        )

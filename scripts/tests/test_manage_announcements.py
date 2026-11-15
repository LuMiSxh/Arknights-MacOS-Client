# SPDX-License-Identifier: MPL-2.0

import argparse
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

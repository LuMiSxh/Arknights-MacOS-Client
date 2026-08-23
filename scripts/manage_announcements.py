#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Prepare the repository-hosted launcher announcement feed."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

from lib.common import (
    PROJECT_DIR,
    VERSION_PATTERN,
    fail,
    require_file,
    run_main,
)
from lib.console import success

FEED_PATH = PROJECT_DIR / "announcements.json"
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,79}$")


def load_feed() -> dict[str, object]:
    try:
        feed = json.loads(require_file(FEED_PATH).read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        fail(f"could not read announcements.json: {error}")
    if feed.get("schemaVersion") != 1 or not isinstance(
        feed.get("announcements"), list
    ):
        fail(
            "announcements.json must use schemaVersion 1 and contain an announcements array"
        )
    return feed


def write_feed(feed: dict[str, object]) -> None:
    FEED_PATH.write_text(
        json.dumps(feed, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )


def validate_url(value: str) -> str | None:
    if not value:
        return None
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc:
        fail("announcement action URL must use HTTPS")
    return value


def validate_version(value: str, *, flag: str) -> str | None:
    if not value:
        return None
    if not VERSION_PATTERN.fullmatch(value):
        fail(f"{flag} must use X.Y.Z with numeric components")
    return value


def validate_timestamp(value: str, *, flag: str) -> tuple[str, datetime] | None:
    if not value:
        return None
    if not value.endswith("Z"):
        fail(f"{flag} must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        fail(f"{flag} must be a valid ISO-8601 UTC timestamp")
    return value, parsed


def set_announcement(arguments: argparse.Namespace) -> None:
    if not ID_PATTERN.fullmatch(arguments.id):
        fail(
            "announcement id must use lowercase letters, numbers, dots, dashes, or underscores"
        )
    if not arguments.title.strip() or len(arguments.title) > 120:
        fail("announcement title must contain 1 to 120 characters")
    body_path = require_file(Path(arguments.body_file).expanduser())
    body = body_path.read_text(encoding="utf-8").strip()
    if not body or len(body) > 4_000:
        fail("announcement Markdown must contain 1 to 4000 characters")
    action_url = validate_url(arguments.action_url)
    action_title = arguments.action_title.strip() or None
    if bool(action_title) != bool(action_url):
        fail("action title and action URL must either both be set or both be empty")
    minimum_version = validate_version(arguments.min_version, flag="--min-version")
    maximum_version = validate_version(arguments.max_version, flag="--max-version")
    starts_at = validate_timestamp(arguments.starts_at, flag="--starts-at")
    ends_at = validate_timestamp(arguments.ends_at, flag="--ends-at")
    if starts_at and ends_at and starts_at[1] >= ends_at[1]:
        fail("--starts-at must be earlier than --ends-at")

    announcement = {
        "id": arguments.id,
        "enabled": True,
        "title": arguments.title.strip(),
        "body": body,
        "actionTitle": action_title,
        "actionURL": action_url,
        "minimumVersion": minimum_version,
        "maximumVersion": maximum_version,
        "startsAt": starts_at[0] if starts_at else None,
        "endsAt": ends_at[0] if ends_at else None,
    }
    feed = load_feed()
    items = feed["announcements"]
    assert isinstance(items, list)
    items[:] = [
        item
        for item in items
        if not isinstance(item, dict) or item.get("id") != arguments.id
    ]
    items.insert(0, announcement)
    write_feed(feed)
    success(
        f"Prepared announcement {arguments.id}; commit announcements.json to main to publish it"
    )


def remove_announcement(arguments: argparse.Namespace) -> None:
    feed = load_feed()
    items = feed["announcements"]
    assert isinstance(items, list)
    remaining = [
        item
        for item in items
        if not isinstance(item, dict) or item.get("id") != arguments.id
    ]
    if len(remaining) == len(items):
        fail(f"announcement not found: {arguments.id}")
    feed["announcements"] = remaining
    write_feed(feed)
    success(
        f"Removed announcement {arguments.id}; commit announcements.json to main to withdraw it"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    set_parser = subparsers.add_parser("set", help="add or replace an announcement")
    set_parser.add_argument("id")
    set_parser.add_argument("title")
    set_parser.add_argument("body_file")
    set_parser.add_argument("--action-title", default="")
    set_parser.add_argument("--action-url", default="")
    set_parser.add_argument("--min-version", default="")
    set_parser.add_argument("--max-version", default="")
    set_parser.add_argument("--starts-at", default="")
    set_parser.add_argument("--ends-at", default="")
    set_parser.set_defaults(function=set_announcement)
    remove_parser = subparsers.add_parser("remove", help="remove an announcement")
    remove_parser.add_argument("id")
    remove_parser.set_defaults(function=remove_announcement)
    arguments = parser.parse_args()
    arguments.function(arguments)


if __name__ == "__main__":
    run_main(main)

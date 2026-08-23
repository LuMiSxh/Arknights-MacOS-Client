#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Show DMG download statistics for published GitHub releases."""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from lib.common import fail, output, require_command, run_main
from lib.console import spinner


@dataclass(frozen=True)
class ReleaseDownloads:
    version: str
    published_at: datetime
    dmg_downloads: int
    recipe_downloads: int


def parse_timestamp(value: object) -> datetime:
    if not isinstance(value, str):
        fail("GitHub returned a release without a publication date")
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        fail(f"GitHub returned an invalid publication date: {value}")


def _asset_downloads(assets: list[object], matches: Callable[[str], bool]) -> int:
    total = 0
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = asset.get("name")
        count = asset.get("download_count")
        if isinstance(name, str) and matches(name.lower()):
            if not isinstance(count, int):
                fail(f"GitHub returned an invalid download count for {name}")
            total += count
    return total


def release_downloads(payload: object) -> list[ReleaseDownloads]:
    if not isinstance(payload, list):
        fail("GitHub returned an invalid releases response")
    releases: list[ReleaseDownloads] = []
    for page in payload:
        if not isinstance(page, list):
            fail("GitHub returned an invalid releases page")
        for release in page:
            if not isinstance(release, dict) or release.get("draft") is True:
                continue
            tag = release.get("tag_name")
            assets = release.get("assets")
            if not isinstance(tag, str) or not isinstance(assets, list):
                fail("GitHub returned incomplete release metadata")
            releases.append(
                ReleaseDownloads(
                    version=tag.removeprefix("v"),
                    published_at=parse_timestamp(release.get("published_at")),
                    dmg_downloads=_asset_downloads(
                        assets, lambda name: name.endswith(".dmg")
                    ),
                    recipe_downloads=_asset_downloads(
                        assets,
                        lambda name: "recipe" in name and name.endswith(".tar.gz"),
                    ),
                )
            )
    return sorted(releases, key=lambda item: item.published_at, reverse=True)


def age_in_days(release: ReleaseDownloads, now: datetime) -> float:
    return max((now - release.published_at).total_seconds() / 86_400, 1 / 24)


def format_age(days: float) -> str:
    if days < 1:
        return f"{days * 24:.1f}h"
    return f"{days:.1f}d"


def render_statistics(releases: list[ReleaseDownloads], now: datetime) -> str:
    if not releases:
        return "No published releases found."
    total_dmg = sum(release.dmg_downloads for release in releases)
    total_recipe = sum(release.recipe_downloads for release in releases)
    rows = []
    for release in releases:
        age = age_in_days(release, now)
        share = release.dmg_downloads / total_dmg * 100 if total_dmg else 0
        rows.append(
            (
                release.version,
                release.published_at.date().isoformat(),
                f"{release.dmg_downloads:,}",
                f"{release.recipe_downloads:,}",
                format_age(age),
                f"{release.dmg_downloads / age:.1f}",
                f"{share:.1f}%",
            )
        )
    headings = ("Version", "Published", "DMG", "Recipe", "Age", "Per day", "Share")
    widths = [
        max(len(headings[index]), *(len(row[index]) for row in rows))
        for index in range(len(headings))
    ]

    def format_row(row: tuple[str, ...]) -> str:
        return "  ".join(value.ljust(widths[index]) for index, value in enumerate(row))

    lines = [format_row(headings), format_row(tuple("-" * width for width in widths))]
    lines.extend(format_row(row) for row in rows)
    lines.extend(
        (
            "",
            f"Total DMG downloads: {total_dmg:,}",
            f"Total recipe downloads: {total_recipe:,}",
        )
    )
    if len(releases) >= 2:
        current, previous = releases[:2]
        combined = current.dmg_downloads + previous.dmg_downloads
        adoption = current.dmg_downloads / combined * 100 if combined else 0
        lines.append(
            f"Latest-version share ({current.version} vs {previous.version}): {adoption:.1f}%"
        )
    lines.extend(
        ("", "GitHub counts asset downloads, not unique users or installations.")
    )
    return "\n".join(lines)


def fetch_releases() -> list[ReleaseDownloads]:
    require_command("gh")
    repository = output(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]
    )
    if not repository:
        fail("could not determine the GitHub repository")
    with spinner("Fetching release statistics from GitHub"):
        raw = output(
            [
                "gh",
                "api",
                "--paginate",
                "--slurp",
                f"repos/{repository}/releases?per_page=100",
            ]
        )
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        fail(f"could not decode the GitHub releases response: {error}")
    return release_downloads(payload)


def main() -> None:
    print(render_statistics(fetch_releases(), datetime.now(UTC)))


if __name__ == "__main__":
    run_main(main)

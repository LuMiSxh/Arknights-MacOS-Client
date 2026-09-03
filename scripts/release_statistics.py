#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Show app-delivery statistics for published GitHub releases."""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from lib.common import fail, output, require_command, run_main
from lib.console import spinner
from lib.project_config import load_project_configuration


@dataclass(frozen=True)
class ReleaseDownloads:
    version: str
    published_at: datetime
    dmg_downloads: int
    sparkle_downloads: int
    recipe_downloads: int

    @property
    def app_downloads(self) -> int:
        return self.dmg_downloads + self.sparkle_downloads


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


def release_downloads(payload: object, *, display_name: str) -> list[ReleaseDownloads]:
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
            version = tag.removeprefix("v")
            dmg_name = f"{display_name}.dmg".lower()
            sparkle_name = f"{display_name} {version}.zip".lower()
            releases.append(
                ReleaseDownloads(
                    version=version,
                    published_at=parse_timestamp(release.get("published_at")),
                    dmg_downloads=_asset_downloads(
                        assets, lambda name, expected=dmg_name: name == expected
                    ),
                    sparkle_downloads=_asset_downloads(
                        assets, lambda name, expected=sparkle_name: name == expected
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
    total_sparkle = sum(release.sparkle_downloads for release in releases)
    total_app = sum(release.app_downloads for release in releases)
    total_recipe = sum(release.recipe_downloads for release in releases)
    rows = []
    for release in releases:
        age = age_in_days(release, now)
        share = release.app_downloads / total_app * 100 if total_app else 0
        rows.append(
            (
                release.version,
                release.published_at.date().isoformat(),
                f"{release.dmg_downloads:,}",
                f"{release.sparkle_downloads:,}",
                f"{release.app_downloads:,}",
                f"{release.recipe_downloads:,}",
                format_age(age),
                f"{release.app_downloads / age:.1f}",
                f"{share:.1f}%",
            )
        )
    headings = (
        "Version",
        "Published",
        "DMG/manual",
        "Sparkle",
        "App total",
        "Recipe",
        "Age",
        "App/day",
        "Share",
    )
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
            f"Total app deliveries: {total_app:,}",
            f"Total DMG/manual package downloads: {total_dmg:,}",
            f"Total Sparkle update downloads: {total_sparkle:,}",
            f"Total recipe downloads: {total_recipe:,}",
        )
    )
    if len(releases) >= 2:
        current, previous = releases[:2]
        combined = current.app_downloads + previous.app_downloads
        adoption = current.app_downloads / combined * 100 if combined else 0
        lines.append(
            f"Latest-version delivery share ({current.version} vs {previous.version}): {adoption:.1f}%"
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
    display_name = load_project_configuration().product.display_name
    return release_downloads(payload, display_name=display_name)


def main() -> None:
    print(render_statistics(fetch_releases(), datetime.now(UTC)))


if __name__ == "__main__":
    run_main(main)

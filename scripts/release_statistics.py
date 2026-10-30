#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Show app-delivery statistics for published GitHub releases."""

from __future__ import annotations

import json

from lib.common import fail, output, require_command, run_main
from lib.project_config import (
    github_asset_stem,
    load_project_configuration,
    sparkle_archive_names,
)

COLUMNS = ("Version", "DMG/manual", "Sparkle", "Recipe")


def release_downloads(
    pages: list[list[dict]], *, display_name: str
) -> list[tuple[str, int, int, int]]:
    """Return (version, DMG, Sparkle, recipe) downloads per published release."""
    stem = github_asset_stem(display_name).lower()
    rows = []
    for release in (item for page in pages for item in page):
        if release.get("draft") is True:
            continue
        version = release["tag_name"].removeprefix("v")
        sparkle_names = sparkle_archive_names(stem, version)
        totals = [0, 0, 0]
        for asset in release["assets"]:
            name, count = asset["name"].lower(), asset["download_count"]
            if name == f"{stem}.dmg":
                totals[0] += count
            elif name in sparkle_names or (
                name.startswith(stem) and name.endswith(".delta")
            ):
                totals[1] += count
            elif "recipe" in name and name.endswith(".tar.gz"):
                totals[2] += count
        rows.append((version, *totals))
    return rows


def traffic_referrers(repository: str) -> str:
    try:
        data = json.loads(
            output(
                [
                    "gh",
                    "api",
                    f"repos/{repository}/traffic/popular/referrers",
                ]
            )
        )
        lines = ["Traffic referrers (last 14 days):"]
        for item in data:
            lines.append(
                f"  {item.get('referrer', '?'):20}  {item.get('count', 0):4} views  {item.get('uniques', 0):4} uniques"
            )
        return "\n".join(lines)
    except Exception:
        return "Traffic data unavailable (requires repo owner access)."


def render_statistics(rows: list[tuple[str, int, int, int]]) -> str:
    if not rows:
        return "No published releases found."
    table = [
        COLUMNS,
        *((version, *(f"{n:,}" for n in rest)) for version, *rest in rows),
    ]
    widths = [max(len(row[i]) for row in table) for i in range(len(COLUMNS))]
    lines = [
        "  ".join(cell.ljust(width) for cell, width in zip(row, widths))
        for row in table
    ]
    dmg, sparkle, recipe = (sum(row[i] for row in rows) for i in (1, 2, 3))
    lines.extend(
        (
            "",
            f"Total app deliveries: {dmg + sparkle:,}",
            f"Total DMG/manual package downloads: {dmg:,}",
            f"Total Sparkle update downloads: {sparkle:,}",
            f"Total recipe downloads: {recipe:,}",
            "",
            "GitHub counts asset downloads, not unique users or installations.",
        )
    )
    return "\n".join(lines)


def main() -> None:
    require_command("gh")
    repository = output(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]
    )
    if not repository:
        fail("could not determine the GitHub repository")
    pages = json.loads(
        output(
            [
                "gh",
                "api",
                "--paginate",
                "--slurp",
                f"repos/{repository}/releases?per_page=100",
            ]
        )
    )
    display_name = load_project_configuration().product.display_name
    print(render_statistics(release_downloads(pages, display_name=display_name)))
    print()
    print(traffic_referrers(repository))


if __name__ == "__main__":
    run_main(main)

#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Find official wallpapers missing from the curated tag manifest, suggest their
tags, and open one issue and one pull request for the whole run.

Gemini suggests tags for each new wallpaper (see `lib/wallpaper_tagger.py`).
Wallpapers with at least one tag go into `WallpaperTags.json` on a dated branch.
Wallpapers without tags are listed as needing manual tags. A maintainer reviews
the pull request and merges it.

`--dry-run` prints the pull request body without any write. `--evaluate N` scores
the suggestions against N already-tagged wallpapers and writes nothing.
"""

from __future__ import annotations

import argparse
import json
import re
from collections.abc import Iterable, Mapping, Sequence
from datetime import UTC, datetime
from pathlib import Path

from lib.common import fail, output, require_command, run, run_main
from lib.console import info, success, warning
from lib.project_config import load_project_configuration
from lib.wallpaper_manifest import (
    entry_order,
    merge_entries,
    read_manifest,
    write_manifest,
)
from lib.wallpaper_tagger import (
    GEMINI_KEY_ENVIRONMENT,
    WallpaperSuggestion,
    WallpaperTagger,
    api_key_from_environment,
    fetch_operator_names,
    known_tag_names,
)
from lib.wallpapers import GalleryWallpaper, fetch_gallery_wallpapers, parse_image_field

# GalleryWallpaper and parse_image_field are re-exported for
# scripts/tests/test_scan_untagged_wallpapers.py.
__all__ = [
    "GalleryWallpaper",
    "fetch_gallery_wallpapers",
    "main",
    "parse_image_field",
]

RESOURCE_SUBDIRECTORY = Path("Resources")
MANIFEST_NAME = "WallpaperTags.json"
AUTOMATED_LABEL = "automated"
AUTOMATED_LABEL_COLOR = "B60205"
AUTOMATED_LABEL_DESCRIPTION = "Created by repository automation"
TAGGING_LABEL = "wallpaper-tagging"
TAGGING_LABEL_COLOR = "d4c5f9"
TAGGING_LABEL_DESCRIPTION = (
    "Needs curated search tags (see docs/development/wallpaper-tagging.md)"
)
WALLPAPER_ID_MARKER = re.compile(r"<!--\s*wallpaper-id:\s*(\S+?)\s*-->")
BASE_BRANCH = "main"
BRANCH_PREFIX = "chore/wallpaper-tags-"
PREVIEW_WIDTH = 240
KNOWN_TAG_LEGEND = (
    "Known tags exist in the manifest or the Global operator list. "
    "Verify new tags before merging."
)


def load_tagged_ids(manifest_path: Path) -> set[str]:
    return set(read_manifest(manifest_path))


def filed_ids_from_bodies(bodies: Iterable[str | None]) -> set[str]:
    """One issue can cover several wallpapers, so every marker counts."""
    return {
        match for body in bodies for match in WALLPAPER_ID_MARKER.findall(body or "")
    }


def already_filed_ids() -> set[str]:
    raw = output(
        [
            "gh",
            "issue",
            "list",
            "--state",
            "open",
            "--label",
            TAGGING_LABEL,
            "--json",
            "body",
            "--limit",
            "500",
        ]
    )
    return filed_ids_from_bodies(issue.get("body") for issue in json.loads(raw or "[]"))


def ensure_labels_exist() -> None:
    existing = output(["gh", "label", "list", "--json", "name", "--limit", "500"])
    names = {label["name"] for label in json.loads(existing or "[]")}
    for name, color, description in (
        (AUTOMATED_LABEL, AUTOMATED_LABEL_COLOR, AUTOMATED_LABEL_DESCRIPTION),
        (TAGGING_LABEL, TAGGING_LABEL_COLOR, TAGGING_LABEL_DESCRIPTION),
    ):
        if name not in names:
            run(
                ["gh", "label", "create", name]
                + ["--color", color, "--description", description]
            )


def issue_title(count: int, today: str) -> str:
    return f"[Wallpaper Tagging] {count} new wallpapers ({today})"


def issue_body(wallpapers: Sequence[GalleryWallpaper]) -> str:
    entries = "\n".join(
        f"- <!-- wallpaper-id: {wallpaper.id} -->\n"
        f"  **{wallpaper.title}** (`{wallpaper.id}`)\n\n"
        f"  ![{wallpaper.title}]({wallpaper.image_url})"
        for wallpaper in wallpapers
    )
    return (
        "## Automated wallpaper tagging\n\n"
        f"{len(wallpapers)} new wallpapers in the Global Fankit gallery need tags.\n\n"
        "If the run opened a pull request, merging it closes this issue. "
        "See `docs/development/wallpaper-tagging.md`.\n\n"
        f"{entries}\n"
    )


def file_issue(wallpapers: Sequence[GalleryWallpaper], today: str) -> int:
    url = output(
        [
            "gh",
            "issue",
            "create",
            "--title",
            issue_title(len(wallpapers), today),
            "--label",
            AUTOMATED_LABEL,
            "--label",
            TAGGING_LABEL,
            "--body",
            issue_body(wallpapers),
        ]
    )
    match = re.search(r"/issues/(\d+)\s*$", url)
    if match is None:
        fail(f"could not read the issue number from: {url}")
    return int(match.group(1))


def find_untagged(
    wallpapers: list[GalleryWallpaper], tagged_ids: set[str], filed_ids: set[str]
) -> list[GalleryWallpaper]:
    return [
        wallpaper
        for wallpaper in wallpapers
        if wallpaper.id not in tagged_ids and wallpaper.id not in filed_ids
    ]


def table_text(text: str) -> str:
    return text.replace("|", "\\|")


def tag_cell(names: Sequence[str]) -> str:
    if not names:
        return "-"
    return ", ".join(f"`{table_text(name)}`" for name in names)


def pull_request_body(
    issue_reference: str,
    wallpapers: Sequence[GalleryWallpaper],
    suggestions: Mapping[str, WallpaperSuggestion],
    manual: Sequence[GalleryWallpaper],
) -> str:
    rows = []
    for wallpaper in wallpapers:
        tags = suggestions[wallpaper.id].tags
        known = [tag.name for tag in tags if tag.known]
        new = [tag.name for tag in tags if not tag.known]
        preview = f'<img src="{wallpaper.image_url}" width="{PREVIEW_WIDTH}">'
        rows.append(
            f"| `{wallpaper.id}` | {table_text(wallpaper.title)} | {preview} "
            f"| {tag_cell(known)} | {tag_cell(new)} |"
        )
    lines = [
        f"Closes {issue_reference}",
        "",
        (
            f"Adds suggested search tags for {len(wallpapers)} new wallpapers. "
            "Check each tag against its preview before you merge."
        ),
        "",
        KNOWN_TAG_LEGEND,
        "",
        "| ID | Title | Preview | Known tags | New tags (verify) |",
        "|---|---|---|---|---|",
        *rows,
    ]
    if manual:
        lines += [
            "",
            "## Needs manual tags",
            "",
            (
                "These wallpapers got no suggested tags. They stay out of this pull "
                "request."
            ),
            "",
            *[
                f"- `{wallpaper.id}` {table_text(wallpaper.title)}"
                for wallpaper in manual
            ],
        ]
    return "\n".join(lines) + "\n"


def suggest_tags(
    wallpapers: Sequence[GalleryWallpaper],
    vocabulary: Sequence[str],
    api_key: str,
) -> dict[str, WallpaperSuggestion]:
    if not api_key:
        return {}
    known = known_tag_names(vocabulary, fetch_operator_names())
    tagger = WallpaperTagger(api_key, vocabulary, known)
    return {wallpaper.id: tagger.suggest(wallpaper) for wallpaper in wallpapers}


def manifest_vocabulary(
    manifest: Mapping[str, list[str]], excluded: Iterable[str] = ()
) -> list[str]:
    skipped = set(excluded)
    return sorted(
        {tag for key, tags in manifest.items() if key not in skipped for tag in tags}
    )


def precision_and_recall(
    pairs: Iterable[tuple[set[str], set[str]]],
) -> tuple[float, float]:
    """Pool counts over all wallpapers. Each pair is (expected, suggested)."""
    matched = suggested_total = expected_total = 0
    for expected, suggested in pairs:
        matched += len(expected & suggested)
        suggested_total += len(suggested)
        expected_total += len(expected)
    precision = matched / suggested_total if suggested_total else 0.0
    recall = matched / expected_total if expected_total else 0.0
    return precision, recall


def manifest_location() -> Path:
    return (
        load_project_configuration().resource_target_directory
        / RESOURCE_SUBDIRECTORY
        / MANIFEST_NAME
    )


def open_tagging_pull_request(
    branch: str,
    manifest_path: Path,
    manifest: Mapping[str, list[str]],
    additions: Mapping[str, list[str]],
    title: str,
    body: str,
    count: int,
) -> None:
    run(["git", "switch", "-c", branch])
    write_manifest(manifest_path, merge_entries(manifest, additions))
    run(["git", "add", str(manifest_path)])
    run(["git", "commit", "-m", f"chore: tag {count} new wallpapers"])
    run(["git", "push", "--set-upstream", "origin", branch])
    run(
        [
            "gh",
            "pr",
            "create",
            "--base",
            BASE_BRANCH,
            "--head",
            branch,
            "--title",
            title,
            "--body",
            body,
            "--label",
            AUTOMATED_LABEL,
            "--label",
            TAGGING_LABEL,
        ]
    )
    # Pull requests opened with GITHUB_TOKEN do not trigger CI, but a workflow
    # dispatch does, and its check satisfies the required status check.
    run(["gh", "workflow", "run", "ci.yml", "--ref", branch])


def evaluate(count: int) -> None:
    api_key = api_key_from_environment()
    if not api_key:
        fail(f"{GEMINI_KEY_ENVIRONMENT} must be set to evaluate tag suggestions")
    manifest = read_manifest(manifest_location())
    tagged = [
        wallpaper
        for wallpaper in fetch_gallery_wallpapers()
        if wallpaper.id in manifest
    ]
    candidates = sorted(
        tagged, key=lambda wallpaper: entry_order(wallpaper.id), reverse=True
    )[:count]
    if not candidates:
        fail("no gallery wallpaper is both tagged and in the manifest")

    # Leave the evaluated entries out of the vocabulary, so the score does not
    # reward copying the expected answer into the prompt.
    vocabulary = manifest_vocabulary(manifest, excluded=[w.id for w in candidates])
    suggestions = suggest_tags(candidates, vocabulary, api_key)
    pairs = []
    for wallpaper in candidates:
        expected = set(manifest[wallpaper.id])
        suggestion = suggestions[wallpaper.id]
        suggested = {tag.name for tag in suggestion.tags}
        pairs.append((expected, suggested))
        print(f"{wallpaper.id}\t{wallpaper.title}")
        print(f"  expected:  {', '.join(sorted(expected)) or '-'}")
        error = f"  (error: {suggestion.error})" if suggestion.error else ""
        print(f"  suggested: {', '.join(sorted(suggested)) or '-'}{error}")
    precision, recall = precision_and_recall(pairs)
    print(
        f"precision: {precision:.2f}  recall: {recall:.2f}  wallpapers: {len(candidates)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="suggest tags and print the pull request body without any write",
    )
    parser.add_argument(
        "--evaluate",
        type=int,
        metavar="N",
        help="score suggestions against N already-tagged wallpapers; writes nothing",
    )
    arguments = parser.parse_args()

    if arguments.evaluate is not None:
        if arguments.evaluate < 1:
            fail("--evaluate needs a positive count")
        evaluate(arguments.evaluate)
        return

    if not arguments.dry_run:
        require_command("gh")
        require_command("git")

    info("Fetching the official Fankit gallery…")
    wallpapers = fetch_gallery_wallpapers()
    manifest_path = manifest_location()
    manifest = read_manifest(manifest_path)
    filed_ids = set() if arguments.dry_run else already_filed_ids()
    untagged = find_untagged(wallpapers, set(manifest), filed_ids)

    if not untagged:
        success(f"All {len(wallpapers)} wallpapers are tagged or already filed.")
        return

    info(f"Found {len(untagged)} untagged wallpaper(s) out of {len(wallpapers)}.")
    api_key = api_key_from_environment()
    if not api_key:
        warning(f"{GEMINI_KEY_ENVIRONMENT} is not set; no tags are suggested.")
    suggestions = suggest_tags(untagged, manifest_vocabulary(manifest), api_key)
    tagged = [w for w in untagged if suggestions.get(w.id) and suggestions[w.id].tags]
    manual = [w for w in untagged if w not in tagged]
    additions = {
        wallpaper.id: [tag.name for tag in suggestions[wallpaper.id].tags]
        for wallpaper in tagged
    }
    today = datetime.now(UTC).date().isoformat()
    pr_title = f"[Wallpaper Tagging] Tag {len(tagged)} new wallpapers ({today})"

    if arguments.dry_run:
        if not tagged:
            info("No wallpaper got tags; no pull request would be opened.")
            return
        print(pull_request_body("#<issue>", tagged, suggestions, manual))
        return

    ensure_labels_exist()
    issue_number = file_issue(untagged, today)
    success(f"Filed issue #{issue_number} for {len(untagged)} new wallpapers.")
    if not tagged:
        warning("No wallpaper got tags; add them by hand. No pull request opened.")
        return

    open_tagging_pull_request(
        branch=f"{BRANCH_PREFIX}{today}",
        manifest_path=manifest_path,
        manifest=manifest,
        additions=additions,
        title=pr_title,
        body=pull_request_body(f"#{issue_number}", tagged, suggestions, manual),
        count=len(tagged),
    )
    success(f"Opened a pull request with tags for {len(tagged)} wallpapers.")


if __name__ == "__main__":
    run_main(main)

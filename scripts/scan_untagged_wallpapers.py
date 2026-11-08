#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Find official wallpapers missing from the curated tag manifest, suggest their
tags, and open one issue and one pull request for the whole run.

Gemini suggests tags for each new wallpaper (see `lib/wallpaper_tagger.py`).
Wallpapers with at least one tag go into `WallpaperTags.json` on a dated branch.
Wallpapers without tags are listed as needing manual tags. A maintainer reviews
the pull request and merges it.

`--tag-only PATH` writes the suggestions for a later `--publish PATH` run, so the
model call and the repository writes can run in separate jobs. `--dry-run` prints
the pull request body without any write. `--evaluate N` scores the suggestions
against N already-tagged wallpapers and writes nothing.
"""

from __future__ import annotations

import argparse
import json
import re
import uuid
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
    SuggestedTag,
    WallpaperSuggestion,
    WallpaperTagger,
    api_key_from_environment,
    fetch_operator_names,
    known_tag_names,
)
from lib.wallpapers import GalleryWallpaper, fetch_gallery_wallpapers

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
SUGGESTION_SCHEMA_VERSION = 1
PREVIEW_WIDTH = 240
KNOWN_TAG_LEGEND = (
    "Known tags exist in the manifest or the Global operator list. "
    "Verify new tags before merging."
)


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


def title(count: int, today: str, *, action: str = "") -> str:
    lead = f"{action} " if action else ""
    return f"[Wallpaper Tagging] {lead}{count} new wallpapers ({today})"


def tagging_branch(today: str) -> str:
    return f"{BRANCH_PREFIX}{today}-{uuid.uuid4().hex[:8]}"


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
            title(len(wallpapers), today),
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


def suggestion_document(
    wallpapers: Sequence[GalleryWallpaper],
    suggestions: Mapping[str, WallpaperSuggestion],
) -> dict[str, object]:
    entries: dict[str, object] = {}
    for wallpaper in wallpapers:
        suggestion = suggestions.get(wallpaper.id)
        entries[wallpaper.id] = {
            "tags": [
                {"name": tag.name, "known": tag.known}
                for tag in (suggestion.tags if suggestion else ())
            ],
            "error": suggestion.error if suggestion else None,
        }
    return {
        "schemaVersion": SUGGESTION_SCHEMA_VERSION,
        "wallpapers": [
            {
                "id": wallpaper.id,
                "title": wallpaper.title,
                "image_url": wallpaper.image_url,
            }
            for wallpaper in wallpapers
        ],
        "suggestions": entries,
    }


def read_suggestion_document(
    path: Path,
) -> tuple[list[GalleryWallpaper], dict[str, WallpaperSuggestion]]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schemaVersion") != SUGGESTION_SCHEMA_VERSION:
        fail(f"{path} is not a version {SUGGESTION_SCHEMA_VERSION} suggestion document")
    wallpapers = [
        GalleryWallpaper(
            id=entry["id"], title=entry["title"], image_url=entry["image_url"]
        )
        for entry in document.get("wallpapers", [])
    ]
    raw_suggestions = document.get("suggestions", {})
    suggestions: dict[str, WallpaperSuggestion] = {}
    for wallpaper in wallpapers:
        entry = raw_suggestions.get(wallpaper.id, {})
        suggestions[wallpaper.id] = WallpaperSuggestion(
            wallpaper.id,
            tuple(
                SuggestedTag(tag["name"], bool(tag["known"]))
                for tag in entry.get("tags", [])
            ),
            entry.get("error"),
        )
    return wallpapers, suggestions


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


def tag_only(output_path: Path) -> None:
    info("Fetching the official Fankit gallery…")
    wallpapers = fetch_gallery_wallpapers()
    manifest = read_manifest(manifest_location())
    untagged = find_untagged(wallpapers, set(manifest), set())
    suggestions: dict[str, WallpaperSuggestion] = {}
    if not untagged:
        success(f"All {len(wallpapers)} wallpapers are tagged.")
    else:
        info(f"Found {len(untagged)} untagged wallpaper(s) out of {len(wallpapers)}.")
        api_key = api_key_from_environment()
        if not api_key:
            warning(f"{GEMINI_KEY_ENVIRONMENT} is not set; no tags are suggested.")
        suggestions = suggest_tags(untagged, manifest_vocabulary(manifest), api_key)
    output_path.write_text(
        json.dumps(suggestion_document(untagged, suggestions), indent=2) + "\n",
        encoding="utf-8",
    )
    success(f"Wrote tag suggestions to {output_path}.")


def publish(path: Path) -> None:
    require_command("gh")
    require_command("git")
    wallpapers, suggestions = read_suggestion_document(path)
    manifest_path = manifest_location()
    manifest = read_manifest(manifest_path)
    untagged = find_untagged(wallpapers, set(manifest), already_filed_ids())
    if not untagged:
        success("All scanned wallpapers are tagged or already filed.")
        return

    info(f"Publishing {len(untagged)} new wallpaper(s).")
    tagged = [w for w in untagged if suggestions.get(w.id) and suggestions[w.id].tags]
    tagged_ids = {w.id for w in tagged}
    manual = [w for w in untagged if w.id not in tagged_ids]
    additions = {
        wallpaper.id: [tag.name for tag in suggestions[wallpaper.id].tags]
        for wallpaper in tagged
    }
    today = datetime.now(UTC).date().isoformat()

    ensure_labels_exist()
    issue_number = file_issue(untagged, today)
    success(f"Filed issue #{issue_number} for {len(untagged)} new wallpapers.")
    if not tagged:
        warning("No wallpaper got tags; add them by hand. No pull request opened.")
        return

    open_tagging_pull_request(
        branch=tagging_branch(today),
        manifest_path=manifest_path,
        manifest=manifest,
        additions=additions,
        title=title(len(tagged), today, action="Tag"),
        body=pull_request_body(f"#{issue_number}", tagged, suggestions, manual),
        count=len(tagged),
    )
    success(f"Opened a pull request with tags for {len(tagged)} wallpapers.")


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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="suggest tags and print the pull request body without any write",
    )
    mode.add_argument(
        "--evaluate",
        type=int,
        metavar="N",
        help="score suggestions against N already-tagged wallpapers; writes nothing",
    )
    mode.add_argument(
        "--tag-only",
        type=Path,
        metavar="PATH",
        help="write tag suggestions for a later --publish run; no repository writes",
    )
    mode.add_argument(
        "--publish",
        type=Path,
        metavar="PATH",
        help="file the issue and pull request from a --tag-only result",
    )
    arguments = parser.parse_args()

    if arguments.evaluate is not None:
        if arguments.evaluate < 1:
            fail("--evaluate needs a positive count")
        evaluate(arguments.evaluate)
        return
    if arguments.tag_only is not None:
        tag_only(arguments.tag_only)
        return
    if arguments.publish is not None:
        publish(arguments.publish)
        return
    if not arguments.dry_run:
        fail("choose --dry-run, --evaluate, --tag-only, or --publish")

    info("Fetching the official Fankit gallery…")
    wallpapers = fetch_gallery_wallpapers()
    manifest = read_manifest(manifest_location())
    untagged = find_untagged(wallpapers, set(manifest), set())

    if not untagged:
        success(f"All {len(wallpapers)} wallpapers are tagged.")
        return

    info(f"Found {len(untagged)} untagged wallpaper(s) out of {len(wallpapers)}.")
    api_key = api_key_from_environment()
    if not api_key:
        warning(f"{GEMINI_KEY_ENVIRONMENT} is not set; no tags are suggested.")
    suggestions = suggest_tags(untagged, manifest_vocabulary(manifest), api_key)
    tagged = [w for w in untagged if suggestions.get(w.id) and suggestions[w.id].tags]
    if not tagged:
        info("No wallpaper got tags; no pull request would be opened.")
        return
    tagged_ids = {w.id for w in tagged}
    manual = [w for w in untagged if w.id not in tagged_ids]
    print(pull_request_body("#<issue>", tagged, suggestions, manual))


if __name__ == "__main__":
    run_main(main)

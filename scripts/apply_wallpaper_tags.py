#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Apply maintainer-supplied tags from a `[Wallpaper Tagging]` issue comment to
the curated tag manifest, then close the issue. Invoked by the
`wallpaper-tag-apply` GitHub Actions workflow on `issue_comment` events; see
`scan_untagged_wallpapers.py` for the issue format this expects.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from lib.common import PROJECT_DIR, fail, require_command, run, run_main
from lib.console import info, success, warning

TAGS_MANIFEST_PATH = (
    PROJECT_DIR / "Sources/ArknightsClient/Resources/WallpaperTags.json"
)
TAGGING_LABEL = "wallpaper-tagging"
WALLPAPER_ID_MARKER = re.compile(r"<!--\s*wallpaper-id:\s*(\S+?)\s*-->")
TAGS_LINE = re.compile(r"(?im)^\s*tags\s*:\s*(.+)$")
ALLOWED_ASSOCIATIONS = {"OWNER", "MEMBER", "COLLABORATOR"}


def parse_tags_line(comment_body: str) -> list[str] | None:
    match = TAGS_LINE.search(comment_body)
    if not match:
        return None
    tags = [tag.strip().lower() for tag in match.group(1).split(",")]
    tags = [tag for tag in tags if tag]
    # De-duplicate while preserving the order the maintainer wrote them in.
    seen: set[str] = set()
    ordered: list[str] = []
    for tag in tags:
        if tag not in seen:
            seen.add(tag)
            ordered.append(tag)
    return ordered or None


def extract_wallpaper_id(issue_body: str) -> str | None:
    match = WALLPAPER_ID_MARKER.search(issue_body)
    return match.group(1) if match else None


def load_manifest(manifest_path: Path) -> dict[str, object]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        fail(f"could not read {manifest_path}: {error}")
    if manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("tags"), dict):
        fail(f"{manifest_path} must use schemaVersion 1 and contain a tags object")
    return manifest


def write_manifest(manifest_path: Path, manifest: dict[str, object]) -> None:
    tags = manifest["tags"]
    manifest["tags"] = dict(sorted(tags.items()))
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )


def apply_tags(
    manifest_path: Path, wallpaper_id: str, tags: list[str]
) -> dict[str, object]:
    manifest = load_manifest(manifest_path)
    manifest["tags"][wallpaper_id] = tags
    write_manifest(manifest_path, manifest)
    return manifest


def commit_and_push(wallpaper_id: str) -> None:
    run(["git", "config", "user.name", "github-actions[bot]"])
    run(
        [
            "git",
            "config",
            "user.email",
            "41898282+github-actions[bot]@users.noreply.github.com",
        ]
    )
    run(["git", "add", str(TAGS_MANIFEST_PATH)])
    run(["git", "commit", "-m", f"chore: tag wallpaper {wallpaper_id}"])
    run(["git", "push"])


def close_issue(issue_number: str, wallpaper_id: str, tags: list[str]) -> None:
    run(
        [
            "gh",
            "issue",
            "comment",
            issue_number,
            "--body",
            f"Recorded tags for `{wallpaper_id}`: {', '.join(tags)}",
        ]
    )
    run(["gh", "issue", "close", issue_number])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--issue-number", required=True)
    parser.add_argument("--issue-body-file", required=True, type=Path)
    parser.add_argument("--comment-body-file", required=True, type=Path)
    parser.add_argument("--comment-author-association", required=True)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="parse and print the tags without writing the manifest or calling gh/git",
    )
    arguments = parser.parse_args()

    association = arguments.comment_author_association.strip().upper()
    if association not in ALLOWED_ASSOCIATIONS:
        info(
            f"Ignoring comment from an author association of {association!r} "
            "(only OWNER, MEMBER, or COLLABORATOR replies are applied)."
        )
        return

    comment_body = arguments.comment_body_file.read_text(encoding="utf-8")
    tags = parse_tags_line(comment_body)
    if tags is None:
        info("Comment does not contain a 'tags: ...' line; nothing to do.")
        return

    issue_body = arguments.issue_body_file.read_text(encoding="utf-8")
    wallpaper_id = extract_wallpaper_id(issue_body)
    if wallpaper_id is None:
        warning("Issue body is missing the wallpaper-id marker; skipping.")
        return

    if arguments.dry_run:
        print(f"{wallpaper_id}\t{','.join(tags)}")
        return

    require_command("git")
    require_command("gh")
    apply_tags(TAGS_MANIFEST_PATH, wallpaper_id, tags)
    commit_and_push(wallpaper_id)
    close_issue(arguments.issue_number, wallpaper_id, tags)
    success(f"Tagged {wallpaper_id} with: {', '.join(tags)}")


if __name__ == "__main__":
    run_main(main)

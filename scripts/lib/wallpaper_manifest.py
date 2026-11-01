# SPDX-License-Identifier: MPL-2.0

"""Read and write `WallpaperTags.json` in the layout the repository uses.

Each entry sits on one line, entries are sorted by numeric wallpaper ID, and the
file ends with one newline. Rewriting the whole file keeps the diff limited to the
new entries.
"""

from __future__ import annotations

import json
from collections.abc import Mapping
from pathlib import Path

from lib.common import fail

# The width the repository's JSON formatter wraps at. The trailing comma counts.
MAX_LINE_WIDTH = 120


def read_manifest(manifest_path: Path) -> dict[str, list[str]]:
    if not manifest_path.is_file():
        return {}
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"could not read {manifest_path}: {error}")
    tags = manifest.get("tags")
    if not isinstance(tags, dict):
        fail(f"{manifest_path} must contain a top-level 'tags' object")
    return tags


def entry_order(entry_id: str) -> tuple[str, int]:
    prefix, _, number = entry_id.rpartition("-")
    return (prefix, int(number))


def merge_entries(
    tags: Mapping[str, list[str]], additions: Mapping[str, list[str]]
) -> dict[str, list[str]]:
    merged = {**tags, **additions}
    return {key: merged[key] for key in sorted(merged, key=entry_order)}


def render_entry(key: str, values: list[str]) -> str:
    """Keep an entry on one line when it fits. Otherwise put each tag on its own line."""
    flat = f"    {json.dumps(key)}: [{', '.join(json.dumps(tag, ensure_ascii=False) for tag in values)}]"
    if len(flat) + 1 <= MAX_LINE_WIDTH:
        return flat
    items = ",\n".join(f"      {json.dumps(tag, ensure_ascii=False)}" for tag in values)
    return f"    {json.dumps(key)}: [\n{items}\n    ]"


def render_manifest(tags: Mapping[str, list[str]]) -> str:
    body = ",\n".join(render_entry(key, values) for key, values in tags.items())
    return f'{{\n  "schemaVersion": 1,\n  "tags": {{\n{body}\n  }}\n}}\n'


def write_manifest(manifest_path: Path, tags: Mapping[str, list[str]]) -> None:
    manifest_path.write_text(render_manifest(tags), encoding="utf-8")

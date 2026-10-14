# SPDX-License-Identifier: MPL-2.0

"""Fill generated blocks of Markdown documents.

A block is `<!-- NAMESPACE:begin NAME -->` to `<!-- NAMESPACE:end NAME -->`. Each
generator owns one namespace, so two generators can share a document.
"""

from __future__ import annotations

import re
from collections.abc import Mapping
from pathlib import Path

from lib.common import fail


def apply_blocks(text: str, blocks: Mapping[str, str], namespace: str) -> str:
    """Replace the body of each block; fail on a missing or unknown block."""
    pattern = re.compile(
        rf"<!-- {re.escape(namespace)}:begin (?P<name>[a-z-]+) -->\n(?P<body>.*?)"
        rf"<!-- {re.escape(namespace)}:end (?P=name) -->\n",
        re.DOTALL,
    )
    seen: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        name = match["name"]
        if name not in blocks:
            fail(f"unknown generated block: {name}")
        seen.add(name)
        return f"<!-- {namespace}:begin {name} -->\n{blocks[name]}<!-- {namespace}:end {name} -->\n"

    result = pattern.sub(replace, text)
    missing = sorted(set(blocks) - seen)
    if missing:
        fail(f"generated block not found in document: {', '.join(missing)}")
    return result


def render_documents(
    root: Path, blocks: Mapping[Path, Mapping[str, str]], namespace: str
) -> dict[Path, str]:
    """Return each document with its blocks filled."""
    return {
        path: apply_blocks((root / path).read_text(encoding="utf-8"), values, namespace)
        for path, values in blocks.items()
    }


def stale_documents(root: Path, documents: Mapping[Path, str]) -> list[Path]:
    """Return the documents on disk that differ from the rendered text."""
    return [
        path
        for path, text in documents.items()
        if (root / path).read_text(encoding="utf-8") != text
    ]


def write_documents(root: Path, documents: Mapping[Path, str]) -> list[Path]:
    """Write the documents that differ from disk; return the changed paths."""
    changed = stale_documents(root, documents)
    for path in changed:
        (root / path).write_text(documents[path], encoding="utf-8")
    return changed

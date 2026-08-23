#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Extract one release section from CHANGELOG.md."""

from __future__ import annotations

import argparse
import re

from lib.common import PROJECT_DIR, fail, run_main


def extract(text: str, version: str) -> str:
    heading = re.compile(
        rf"^## \[{re.escape(version)}\](?:[ \t]+-[ \t]+[^\r\n]+)?$",
        re.MULTILINE,
    )
    match = heading.search(text)
    if match is None:
        fail(f"CHANGELOG.md does not contain a {version} release section")
    start = match.end()
    next_heading = re.search(r"^## \[", text[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(text)
    body = text[start:end].strip()
    if not body:
        fail(f"CHANGELOG.md section {version} is empty")
    return body


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    arguments = parser.parse_args()
    text = (PROJECT_DIR / "CHANGELOG.md").read_text(encoding="utf-8")
    print(extract(text, arguments.version))


if __name__ == "__main__":
    run_main(main)

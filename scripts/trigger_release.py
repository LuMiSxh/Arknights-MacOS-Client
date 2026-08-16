#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Validate and trigger the manual GitHub draft-release workflow."""

from __future__ import annotations

import argparse
import re

from common import (
    PROJECT_DIR,
    ScriptError,
    fail,
    info,
    output,
    require_commands,
    run,
    run_main,
    success,
)

VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def trigger(version: str) -> None:
    if not VERSION_PATTERN.fullmatch(version):
        fail("version must use X.Y.Z")
    require_commands(("gh", "git"))
    changelog = PROJECT_DIR / "CHANGELOG.md"
    if f"## [{version}]" not in changelog.read_text(encoding="utf-8"):
        fail(f"CHANGELOG.md does not contain a {version} release section")
    if output(["git", "status", "--porcelain"], cwd=PROJECT_DIR):
        fail("the working tree must be clean")

    branch = output(
        ["git", "symbolic-ref", "--quiet", "--short", "HEAD"], cwd=PROJECT_DIR
    )
    if not branch:
        fail("releases must be triggered from a branch")
    if branch != "main":
        fail("releases must be triggered from main after the release branch is merged")
    try:
        upstream = output(
            [
                "git",
                "rev-parse",
                "--abbrev-ref",
                "--symbolic-full-name",
                "@{upstream}",
            ],
            cwd=PROJECT_DIR,
        )
    except ScriptError:
        fail("the current branch has no upstream")

    info("Refreshing the upstream branch")
    run(["git", "fetch", "--quiet"], cwd=PROJECT_DIR)
    if output(["git", "rev-parse", "HEAD"], cwd=PROJECT_DIR) != output(
        ["git", "rev-parse", upstream], cwd=PROJECT_DIR
    ):
        fail(f"the current branch must match {upstream}")
    run(["gh", "auth", "status"], capture=True)
    info(f"Triggering the v{version} draft release from {branch}")
    run(
        [
            "gh",
            "workflow",
            "run",
            "release.yml",
            "--ref",
            branch,
            "--field",
            f"version={version}",
        ],
        cwd=PROJECT_DIR,
    )
    success(f"Triggered draft release v{version}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    arguments = parser.parse_args()
    trigger(arguments.version)


if __name__ == "__main__":
    run_main(main)

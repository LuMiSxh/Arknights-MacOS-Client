#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Validate and trigger the manual GitHub draft-release workflow."""

from __future__ import annotations

import argparse

from lib.common import (
    PROJECT_DIR,
    ScriptError,
    fail,
    output,
    require_commands,
    run,
    run_main,
)
from lib.console import info, spinner, success
from lib.project_config import load_project_configuration
from release_validation import validate_release


def trigger(version: str) -> None:
    configuration = load_project_configuration()
    validate_release(
        version,
        PROJECT_DIR / "CHANGELOG.md",
        configuration.product.marketing_version,
    )
    require_commands(("gh", "git"))
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

    with spinner("Refreshing the upstream branch"):
        run(["git", "fetch", "--quiet"], cwd=PROJECT_DIR)
    if output(["git", "rev-parse", "HEAD"], cwd=PROJECT_DIR) != output(
        ["git", "rev-parse", upstream], cwd=PROJECT_DIR
    ):
        fail(f"the current branch must match {upstream}")
    with spinner("Checking GitHub authentication"):
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

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Check or format Swift, Python, and C/Objective-C sources."""

from __future__ import annotations

import argparse
import os
from collections.abc import Callable
from pathlib import Path

from lib.common import PROJECT_DIR, info, run, run_main, success
from lib.project_config import load_project_configuration
from localization import synchronize_localization
from runtime_config import validate_config
from swift_tests import run_level as run_swift_test_level

RUFF = ("uv", "tool", "run", "--from", "ruff==0.16.3", "ruff")


def check_localization() -> None:
    info("Checking generated localization resources")
    synchronize_localization(write=False)


def format_localization() -> None:
    info("Generating localization resources")
    synchronize_localization(write=True)


def shim_sources() -> list[Path]:
    runtime_support = PROJECT_DIR / "RuntimeSupport"
    return sorted(runtime_support.rglob("*.c")) + sorted(runtime_support.rglob("*.m"))


def workflow_files() -> list[Path]:
    return sorted((PROJECT_DIR / ".github" / "workflows").glob("*.yml"))


def handwritten_swift_sources() -> list[Path]:
    sources = sorted((PROJECT_DIR / "Sources").rglob("*.swift"))
    tests = sorted((PROJECT_DIR / "Tests").rglob("*.swift"))
    return [
        path
        for path in [*sources, *tests]
        if not path.name.startswith("GeneratedStringSymbols_")
    ]


def check_swift() -> None:
    info("Linting Swift sources")
    run(
        [
            "swift",
            "format",
            "lint",
            "--configuration",
            ".swift-format",
            "--strict",
            *handwritten_swift_sources(),
        ],
        cwd=PROJECT_DIR,
    )
    run_swift_test_level("unit")


def format_swift() -> None:
    info("Formatting Swift sources")
    run(
        [
            "swift",
            "format",
            "format",
            "--configuration",
            ".swift-format",
            "--in-place",
            *handwritten_swift_sources(),
        ],
        cwd=PROJECT_DIR,
    )


def check_scripts() -> None:
    info("Linting Python scripts")
    run([*RUFF, "check", "scripts"], cwd=PROJECT_DIR)
    run([*RUFF, "format", "--check", "scripts"], cwd=PROJECT_DIR)
    load_project_configuration()
    validate_config(PROJECT_DIR / "runtime.json")
    environment = os.environ.copy()
    environment.pop("VIRTUAL_ENV", None)
    info("Linting GitHub Actions workflows")
    run(
        ["uv", "run", "--locked", "actionlint", *workflow_files()],
        cwd=PROJECT_DIR,
        environment=environment,
    )
    info("Running the Python script test suite")
    run(
        ["uv", "run", "--locked", "pytest", "-q"],
        cwd=PROJECT_DIR,
        environment=environment,
    )


def format_scripts() -> None:
    info("Formatting Python scripts")
    run([*RUFF, "format", "scripts"], cwd=PROJECT_DIR)


def check_shim() -> None:
    info("Linting C/Objective-C shims")
    run(
        ["xcrun", "clang-format", "--dry-run", "--Werror", *shim_sources()],
        cwd=PROJECT_DIR,
    )


def format_shim() -> None:
    info("Formatting C/Objective-C shims")
    run(["xcrun", "clang-format", "-i", *shim_sources()], cwd=PROJECT_DIR)


TARGETS: dict[str, tuple[Callable[[], None], Callable[[], None]]] = {
    "localization": (check_localization, format_localization),
    "swift": (check_swift, format_swift),
    "scripts": (check_scripts, format_scripts),
    "shim": (check_shim, format_shim),
}


def run_mode(mode: str, target: str) -> None:
    names = TARGETS if target == "all" else (target,)
    for name in names:
        checker, formatter = TARGETS[name]
        (checker if mode == "check" else formatter)()
    success(f"{mode} complete ({target})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "format"))
    parser.add_argument("target", nargs="?", choices=(*TARGETS, "all"), default="all")
    arguments = parser.parse_args()
    run_mode(arguments.mode, arguments.target)


if __name__ == "__main__":
    run_main(main)

#!/usr/bin/env -S uv run --locked
# SPDX-License-Identifier: MPL-2.0

"""Check or format project sources."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from pathlib import Path

from lib.common import PROJECT_DIR, run, run_main
from lib.console import info, success
from lib.project_config import load_project_configuration
from localization import prepare_localization
from runtime_config import validate_config
from swift_tests import run_level as run_swift_test_level

RUFF = (sys.executable, "-m", "ruff")


def check_localization() -> None:
    info("Checking localization catalogs")
    prepare_localization()


def format_localization() -> None:
    info("Regenerating localization symbols")
    prepare_localization(force=True)


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
    info("Linting GitHub Actions workflows")
    run(
        ["actionlint", *workflow_files()],
        cwd=PROJECT_DIR,
    )
    info("Running the Python script test suite")
    run(
        [sys.executable, "-m", "pytest", "-q"],
        cwd=PROJECT_DIR,
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


def check_website() -> None:
    info("Checking website sources")
    run(["pnpm", "check"], cwd=PROJECT_DIR / "web")
    run(["pnpm", "format:check"], cwd=PROJECT_DIR / "web")


def format_website() -> None:
    info("Formatting website sources")
    run(["pnpm", "format"], cwd=PROJECT_DIR / "web")


TARGETS: dict[str, tuple[Callable[[], None], Callable[[], None]]] = {
    "localization": (check_localization, format_localization),
    "swift": (check_swift, format_swift),
    "scripts": (check_scripts, format_scripts),
    "shim": (check_shim, format_shim),
    "web": (check_website, format_website),
}
DEFAULT_TARGETS = ("localization", "swift", "scripts", "shim")


def run_mode(mode: str, target: str) -> None:
    names = DEFAULT_TARGETS if target == "all" else (target,)
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

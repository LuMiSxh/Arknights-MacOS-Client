#!/usr/bin/env -S uv run --locked
# SPDX-License-Identifier: MPL-2.0

"""Check or format project sources."""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Callable
from pathlib import Path

from lib.bundled_resources import registry_drift
from lib.common import PROJECT_DIR, run, run_main
from lib.console import info, success, warning
from lib.licenses import check_all
from lib.project_config import load_project_configuration
from lib.runtime_update import check as check_runtime_pin
from runtime_config import validate_config
from swift_tests import run_level as run_swift_test_level

RUFF = (sys.executable, "-m", "ruff")


def shim_sources() -> list[Path]:
    runtime_support = PROJECT_DIR / "RuntimeSupport"
    return sorted(runtime_support.rglob("*.c")) + sorted(runtime_support.rglob("*.m"))


def workflow_files() -> list[Path]:
    return sorted((PROJECT_DIR / ".github" / "workflows").glob("*.yml"))


def swift_sources() -> list[Path]:
    sources = sorted((PROJECT_DIR / "Sources").rglob("*.swift"))
    tests = sorted((PROJECT_DIR / "Tests").rglob("*.swift"))
    return [*sources, *tests]


SWIFT_SOURCE_DIR = PROJECT_DIR / "Sources" / "ArknightsClient"
LOWER_LAYERS = ("Shared", "Infrastructure")
TYPE_DECLARATION = re.compile(
    r"^(?:(?:public|internal|final|indirect|nonisolated|@\w+(?:\([^)]*\))?)\s+)*"
    r"(?:struct|class|enum|protocol|actor|typealias)\s+([A-Z]\w*)",
    re.MULTILINE,
)
SWIFT_COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)


def strip_comments(source: str) -> str:
    return SWIFT_COMMENT.sub(lambda match: re.sub(r"[^\n]", "", match.group()), source)


def declared_types(root: Path) -> set[str]:
    names: set[str] = set()
    for path in root.rglob("*.swift"):
        names.update(TYPE_DECLARATION.findall(strip_comments(path.read_text("utf-8"))))
    return names


def layering_violations(source_dir: Path = SWIFT_SOURCE_DIR) -> list[str]:
    """Return `file:line: Type` entries where a lower layer names a Features type."""
    lower_names = set().union(
        *(declared_types(source_dir / name) for name in LOWER_LAYERS)
    )
    feature_names = declared_types(source_dir / "Features") - lower_names
    if not feature_names:
        return []
    pattern = re.compile(r"\b(" + "|".join(sorted(feature_names)) + r")\b")
    violations: list[str] = []
    for layer in LOWER_LAYERS:
        for path in sorted((source_dir / layer).rglob("*.swift")):
            source = strip_comments(path.read_text("utf-8"))
            for number, line in enumerate(source.splitlines(), start=1):
                for match in pattern.finditer(line):
                    violations.append(
                        f"{path.relative_to(source_dir)}:{number}: {match.group(1)}"
                    )
    return violations


def check_layering() -> None:
    info("Checking that Shared and Infrastructure do not reference Features types")
    violations = layering_violations()
    if violations:
        raise SystemExit(
            "Shared and Infrastructure must not reference Features types:\n"
            + "\n".join(violations)
        )


def check_swift() -> None:
    info("Linting Swift sources")
    check_layering()
    run(
        [
            "swift",
            "format",
            "lint",
            "--configuration",
            ".swift-format",
            "--strict",
            *swift_sources(),
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
            *swift_sources(),
        ],
        cwd=PROJECT_DIR,
    )


def check_scripts() -> None:
    info("Linting Python scripts")
    run([*RUFF, "check", "scripts"], cwd=PROJECT_DIR)
    run([*RUFF, "format", "--check", "scripts"], cwd=PROJECT_DIR)
    configuration = load_project_configuration()
    info("Checking the bundled resource registry")
    drift = registry_drift(configuration)
    if drift:
        raise SystemExit(
            "Swift BundledResource and scripts/lib/bundled_resources.py differ:\n"
            + "\n".join(drift)
        )
    validate_config(PROJECT_DIR / "runtime.json")
    info("Checking the third-party license inventory")
    for message in check_all(PROJECT_DIR):
        warning(message)
    info("Checking the runtime pin and its generated blocks")
    check_runtime_pin(PROJECT_DIR)
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
    "swift": (check_swift, format_swift),
    "scripts": (check_scripts, format_scripts),
    "shim": (check_shim, format_shim),
    "web": (check_website, format_website),
}
DEFAULT_TARGETS = ("swift", "scripts", "shim")


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

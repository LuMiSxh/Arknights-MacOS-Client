# SPDX-License-Identifier: MPL-2.0

"""Find design literals in feature Swift code that should read the theme from `Shared/UI`.

Each rule names one literal family. Existing violations are listed in the allowlist as
`path:rule` entries. An entry that matches nothing is an error, so the list shrinks as the
migration proceeds.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from lib.project_config import (
    DESIGN_LINT_ALLOWLIST,
    DESIGN_LINT_EXCLUDED_DIRECTORIES,
    DESIGN_LINT_SOURCE_ROOT,
)

ANIMATION_CALLS = (
    "spring",
    "snappy",
    "smooth",
    "easeInOut",
    "easeIn",
    "easeOut",
    "interactiveSpring",
    "bouncy",
)
# One pattern per literal family. `.linear(` is left out on purpose: WallpaperColorExtractor
# has a `linear` function that is not an animation.
RULES: dict[str, re.Pattern[str]] = {
    "raw-color": re.compile(r"Color\(\s*(?:red:|\.sRGB)|\.(?:white|black)\.opacity\("),
    "numeric-radius": re.compile(r"cornerRadius:\s*\d"),
    "raw-animation": re.compile(r"\.(?:" + "|".join(ANIMATION_CALLS) + r")\("),
    "raw-glass": re.compile(r"\.glassEffect\("),
    "system-font": re.compile(r"\.font\(\.system\(size:"),
}
# Masking strings before cutting comments keeps a `//` inside a string from hiding the line.
_STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
_LINE_COMMENT = re.compile(r"//.*")


@dataclass(frozen=True)
class Violation:
    """One line in a scanned Swift file that matches a rule."""

    path: str
    line: int
    rule: str
    text: str


def _code_of(line: str) -> str:
    return _LINE_COMMENT.sub("", _STRING_LITERAL.sub('""', line))


def scan(root: Path) -> list[Violation]:
    """Return every rule match in the feature Swift files under `root`, in path and line order."""
    excluded = tuple(root / directory for directory in DESIGN_LINT_EXCLUDED_DIRECTORIES)
    violations: list[Violation] = []
    for path in sorted((root / DESIGN_LINT_SOURCE_ROOT).rglob("*.swift")):
        if any(path.is_relative_to(directory) for directory in excluded):
            continue
        relative = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, start=1):
            code = _code_of(line)
            for rule, pattern in RULES.items():
                if pattern.search(code):
                    violations.append(Violation(relative, number, rule, line.strip()))
    return violations


def _load_allowlist(path: Path) -> tuple[set[tuple[str, str]], list[str]]:
    """Return the `(path, rule)` entries and one problem for each malformed line."""
    if not path.is_file():
        return set(), [f"{path.name}: allowlist is missing"]
    entries: set[tuple[str, str]] = set()
    problems: list[str] = []
    for number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        file_path, separator, rule = entry.rpartition(":")
        if not separator or not file_path or rule not in RULES:
            problems.append(
                f"{path.name}:{number}: expected path:rule with a known rule, got {entry!r}"
            )
        elif (file_path, rule) in entries:
            problems.append(f"{path.name}:{number}: duplicate entry {entry}")
        else:
            entries.add((file_path, rule))
    return entries, problems


def check(root: Path) -> list[str]:
    """Return one message for each violation not allowlisted and each stale or malformed entry."""
    allowed, problems = _load_allowlist(root / DESIGN_LINT_ALLOWLIST)
    matched: set[tuple[str, str]] = set()
    for violation in scan(root):
        key = (violation.path, violation.rule)
        if key in allowed:
            matched.add(key)
        else:
            problems.append(
                f"{violation.path}:{violation.line}: {violation.rule}: {violation.text}"
            )
    problems.extend(
        f"{path}:{rule}: allowlist entry matches no violation; remove it"
        for path, rule in sorted(allowed - matched)
    )
    return problems

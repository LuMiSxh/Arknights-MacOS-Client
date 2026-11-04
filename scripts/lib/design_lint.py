# SPDX-License-Identifier: MPL-2.0

"""Find design literals in feature Swift code that should read the theme from `Shared/UI`.

Each rule names one literal family. Existing violations are listed in the allowlist as
`path:rule:count` entries. The count is the exact number of violations the file may have for
that rule. A count that differs from the scan is an error, so a new violation in a listed file
fails. An entry that matches nothing is an error, so the list shrinks as the migration proceeds.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from lib.project_config import (
    DESIGN_LINT_ALLOWLIST,
    DESIGN_LINT_EXCLUDED_DIRECTORIES,
    DESIGN_LINT_EXEMPT_FILES,
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
# One pattern per literal family. A bare `.linear(` is left out on purpose: WallpaperColorExtractor
# has a `linear` function that is not an animation, so only `.linear(duration:` counts.
RULES: dict[str, re.Pattern[str]] = {
    "raw-color": re.compile(r"Color\(\s*(?:red:|\.sRGB)|\.(?:white|black)\.opacity\("),
    "raw-hue": re.compile(r"Color\(\s*hue:"),
    "raw-black": re.compile(r"\bColor\.black\b(?!\.opacity\()"),
    "raw-white-foreground": re.compile(r"\.foregroundStyle\(\s*\.white\s*\)"),
    "numeric-radius": re.compile(r"cornerRadius:\s*\d"),
    "raw-animation": re.compile(
        r"\.(?:" + "|".join(ANIMATION_CALLS) + r")\(|\.linear\(duration:"
    ),
    "raw-glass": re.compile(r"\.glassEffect\("),
    "system-font": re.compile(r"\.font\(\.system\(size:"),
    "font-weight": re.compile(
        r"\bweight:\s*\.(?:bold|heavy)\b|\.fontWeight\(\s*\.(?:bold|heavy)\b|\.bold\(\)"
    ),
    "detached-task": re.compile(r"\bTask\.detached\b"),
}
# Concurrency rules apply to every Swift file under the source root, including the files the
# design-literal rules skip.
SOURCE_WIDE_RULES = frozenset({"detached-task"})
# Spacing and padding literals sit on the 4 pt grid. 0, 1 and 2 stay allowed for hairlines and
# the 2 pt step inside small controls. The rule is separate from RULES because it compares values.
OFF_GRID_RULE = "off-grid-spacing"
OFF_GRID_SPACING = re.compile(
    r"\bspacing:\s*(\d+(?:\.\d+)?)\b|\.padding\(\s*(?:\.\w+\s*,\s*)?(\d+(?:\.\d+)?)\s*\)"
)
ALLOWED_SMALL_SPACING = frozenset({1.0, 2.0})
KNOWN_RULES = frozenset({*RULES, OFF_GRID_RULE})
# Allowlist entries look like `path:rule:count`; the count is at least 1.
ENTRY = re.compile(r"([^:]+):([a-z-]+):([1-9][0-9]*)")
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


def _has_off_grid_spacing(code: str) -> bool:
    """Return True when a spacing or padding literal in `code` is off the 4 pt grid."""
    for match in OFF_GRID_SPACING.finditer(code):
        value = float(match.group(1) or match.group(2))
        if value % 4 != 0 and value not in ALLOWED_SMALL_SPACING:
            return True
    return False


def scan(root: Path) -> list[Violation]:
    """Return every rule match in the Swift files under `root`, in path and line order."""
    excluded = tuple(root / directory for directory in DESIGN_LINT_EXCLUDED_DIRECTORIES)
    exempt = {root / path for path in DESIGN_LINT_EXEMPT_FILES}
    violations: list[Violation] = []
    for path in sorted((root / DESIGN_LINT_SOURCE_ROOT).rglob("*.swift")):
        skipped = path in exempt or any(
            path.is_relative_to(directory) for directory in excluded
        )
        rules = [
            (rule, pattern)
            for rule, pattern in RULES.items()
            if not skipped or rule in SOURCE_WIDE_RULES
        ]
        relative = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, start=1):
            code = _code_of(line)
            for rule, pattern in rules:
                if pattern.search(code):
                    violations.append(Violation(relative, number, rule, line.strip()))
            if not skipped and _has_off_grid_spacing(code):
                violations.append(
                    Violation(relative, number, OFF_GRID_RULE, line.strip())
                )
    return violations


def _load_allowlist(path: Path) -> tuple[dict[tuple[str, str], int], list[str]]:
    """Return the expected count for each `(path, rule)` and one problem per malformed line."""
    if not path.is_file():
        return {}, [f"{path.name}: allowlist is missing"]
    expected: dict[tuple[str, str], int] = {}
    problems: list[str] = []
    for number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        parsed = ENTRY.fullmatch(entry)
        if parsed is None or parsed[2] not in KNOWN_RULES:
            problems.append(
                f"{path.name}:{number}: expected path:rule:count with a known rule "
                f"and a count of at least 1, got {entry!r}"
            )
        elif (parsed[1], parsed[2]) in expected:
            problems.append(f"{path.name}:{number}: duplicate entry {entry}")
        else:
            expected[(parsed[1], parsed[2])] = int(parsed[3])
    return expected, problems


def check(root: Path) -> list[str]:
    """Return one message for each unexpected violation and each stale or miscounted entry."""
    expected, problems = _load_allowlist(root / DESIGN_LINT_ALLOWLIST)
    violations = scan(root)
    found = Counter((violation.path, violation.rule) for violation in violations)
    for violation in violations:
        key = (violation.path, violation.rule)
        if found[key] > expected.get(key, 0):
            problems.append(
                f"{violation.path}:{violation.line}: {violation.rule}: {violation.text}"
            )
    for (path, rule), allowed in sorted(expected.items()):
        actual = found.get((path, rule), 0)
        if actual == 0:
            problems.append(
                f"{path}:{rule}: allowlist entry matches no violation; remove it"
            )
        elif actual != allowed:
            problems.append(
                f"{path}:{rule}: allowlist allows {allowed}, found {actual}; "
                "review and update the count"
            )
    return problems

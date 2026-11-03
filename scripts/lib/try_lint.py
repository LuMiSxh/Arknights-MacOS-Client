# SPDX-License-Identifier: MPL-2.0

"""Find silent `try?` in the Swift targets that own filesystem, process, and network work.

A `try?` passes only when its line or the line above carries `// best effort:`, and that form is for
removing app-owned temporary files. Other failures go through `log.attempt` or are handled.
Each `path:silent-try:count` entry in the allowlist names a file and the exact number of unmarked
`try?` it may keep. A count that differs from the scan is an error, so a new hit in a listed file
fails until its count is reviewed.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

TRY_LINT_SOURCE_ROOTS = (
    Path("Sources/ArknightsInfrastructure"),
    Path("Sources/ArknightsGameInstallation"),
    Path("Sources/ArknightsGameRuntime"),
)
TRY_LINT_ALLOWLIST = Path("scripts/try-lint-allowlist.txt")
RULE = "silent-try"
BEST_EFFORT_MARKER = "// best effort:"
SILENT_TRY = re.compile(r"\btry\?")
# Allowlist entries look like `path:silent-try:count`; the count is at least 1.
ENTRY = re.compile(rf"([^:]+):{RULE}:([1-9][0-9]*)")
# Masking strings before cutting comments keeps a `//` inside a string from hiding the line.
_STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
_LINE_COMMENT = re.compile(r"//.*")


@dataclass(frozen=True)
class Violation:
    """One unmarked `try?` in a Swift source file."""

    path: str
    line: int
    text: str


def _code_of(line: str) -> str:
    return _LINE_COMMENT.sub("", _STRING_LITERAL.sub('""', line))


def scan(root: Path) -> list[Violation]:
    """Return every `try?` without a best-effort marker, in path and line order."""
    violations: list[Violation] = []
    for source_root in TRY_LINT_SOURCE_ROOTS:
        for path in sorted((root / source_root).rglob("*.swift")):
            relative = path.relative_to(root).as_posix()
            lines = path.read_text(encoding="utf-8").splitlines()
            for number, line in enumerate(lines, start=1):
                if not SILENT_TRY.search(_code_of(line)):
                    continue
                previous = lines[number - 2] if number > 1 else ""
                if BEST_EFFORT_MARKER in line or BEST_EFFORT_MARKER in previous:
                    continue
                violations.append(Violation(relative, number, line.strip()))
    return violations


def _load_allowlist(path: Path) -> tuple[dict[str, int], list[str]]:
    """Return the expected count for each path and one problem for each malformed line."""
    if not path.is_file():
        return {}, [f"{path.name}: allowlist is missing"]
    expected: dict[str, int] = {}
    problems: list[str] = []
    for number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        parsed = ENTRY.fullmatch(entry)
        if parsed is None:
            problems.append(
                f"{path.name}:{number}: expected path:{RULE}:count, got {entry!r}"
            )
        elif parsed[1] in expected:
            problems.append(f"{path.name}:{number}: duplicate entry {entry}")
        else:
            expected[parsed[1]] = int(parsed[2])
    return expected, problems


def check(root: Path) -> list[str]:
    """Return one message for each unmarked `try?` beyond its allowlist count, and each stale entry."""
    expected, problems = _load_allowlist(root / TRY_LINT_ALLOWLIST)
    violations = scan(root)
    found = Counter(violation.path for violation in violations)
    for violation in violations:
        if found[violation.path] > expected.get(violation.path, 0):
            problems.append(
                f"{violation.path}:{violation.line}: {RULE}: {violation.text}"
            )
    for path, allowed in sorted(expected.items()):
        actual = found.get(path, 0)
        if actual == 0:
            problems.append(
                f"{path}:{RULE}: allowlist entry matches no violation; remove it"
            )
        elif actual != allowed:
            problems.append(
                f"{path}:{RULE}: allowlist allows {allowed}, found {actual}; "
                "review and update the count"
            )
    return problems

# SPDX-License-Identifier: MPL-2.0

"""Find silent `try?` in the Swift targets that own filesystem, process, and network work.

A `try?` passes only when its line or the line above carries `// best effort:`, and that form is for
removing app-owned temporary files. Other failures go through `log.attempt` or are handled.
Each `path:silent-try:count` entry in the allowlist names a file and the exact number of unmarked
`try?` it may keep. A count that differs from the scan is an error, so a new hit in a listed file
fails until its count is reviewed.
"""

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from lib.allowlist import code_of, load_allowlist

TRY_LINT_SOURCE_ROOTS = (
    Path("Sources/ArknightsInfrastructure"),
    Path("Sources/ArknightsGameInstallation"),
    Path("Sources/ArknightsGameRuntime"),
)
TRY_LINT_ALLOWLIST = Path("scripts/try-lint-allowlist.txt")
RULE = "silent-try"
BEST_EFFORT_MARKER = "// best effort:"
SILENT_TRY = re.compile(r"\btry\?")


@dataclass(frozen=True, slots=True)
class Violation:
    """One unmarked `try?` in a Swift source file."""

    path: str
    line: int
    text: str


def scan(root: Path) -> list[Violation]:
    """Return every `try?` without a best-effort marker, in path and line order."""
    violations: list[Violation] = []
    for source_root in TRY_LINT_SOURCE_ROOTS:
        for path in sorted((root / source_root).rglob("*.swift")):
            relative = path.relative_to(root).as_posix()
            lines = path.read_text(encoding="utf-8").splitlines()
            for number, line in enumerate(lines, start=1):
                if not SILENT_TRY.search(code_of(line)):
                    continue
                previous = lines[number - 2] if number > 1 else ""
                if BEST_EFFORT_MARKER in line or BEST_EFFORT_MARKER in previous:
                    continue
                violations.append(Violation(relative, number, line.strip()))
    return violations


def _load_allowlist(path: Path) -> tuple[dict[tuple[str, str], int], list[str]]:
    """Return the expected count for each path and one problem for each malformed line."""
    return load_allowlist(
        path,
        rules=frozenset({RULE}),
        expected_message="{name}:{number}: expected path:{rule}:count, got {entry!r}",
    )


def check(root: Path) -> list[str]:
    """Return one message for each unmarked `try?` beyond its allowlist count, and each stale entry."""
    expected, problems = _load_allowlist(root / TRY_LINT_ALLOWLIST)
    violations = scan(root)
    found = Counter((violation.path, RULE) for violation in violations)
    for violation in violations:
        if found[(violation.path, RULE)] > expected.get((violation.path, RULE), 0):
            problems.append(
                f"{violation.path}:{violation.line}: {RULE}: {violation.text}"
            )
    for (path, _), allowed in sorted(expected.items()):
        actual = found.get((path, RULE), 0)
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

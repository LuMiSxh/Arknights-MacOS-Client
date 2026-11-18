# SPDX-License-Identifier: MPL-2.0

"""Find real sleeps in Swift tests. Tests wait on events, bounded timeouts, or injected clocks.

Each `path:real-sleep:count` entry in the allowlist names a file and the exact number of its
genuine sleeps: wall-clock timeout bounds or live-contract probes. A count that differs from the
scan is an error, so a new sleep in a listed file fails until its count is reviewed.
"""

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from lib.allowlist import code_of, load_allowlist

TEST_SOURCE_ROOT = Path("Tests")
TEST_SLEEP_ALLOWLIST = Path("scripts/config/test-sleep-allowlist.txt")
RULE = "real-sleep"
# A method call such as `clock.sleep(until:)` is not a real sleep, so the bare C form skips a
# preceding `.` or identifier character.
REAL_SLEEP = re.compile(
    r"\bTask\.sleep\s*\(|\bThread\.sleep\s*\(|\busleep\s*\(|(?<![\w.])sleep\s*\("
)
# A `func sleep(` declaration implements the Clock protocol and waits on nothing.
FAKE_CLOCK_DECLARATION = re.compile(r"\bfunc\s+sleep\s*\(")


@dataclass(frozen=True, slots=True)
class Violation:
    """One line in a Swift test file that calls a real sleep."""

    path: str
    line: int
    text: str


def scan(root: Path) -> list[Violation]:
    """Return every real-sleep call in the Swift test files under `root`, in path and line order."""
    violations: list[Violation] = []
    for path in sorted((root / TEST_SOURCE_ROOT).rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, start=1):
            code = code_of(line)
            if REAL_SLEEP.search(code) and not FAKE_CLOCK_DECLARATION.search(code):
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
    """Return one message for each unexpected real sleep and each stale or miscounted entry."""
    expected, problems = _load_allowlist(root / TEST_SLEEP_ALLOWLIST)
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

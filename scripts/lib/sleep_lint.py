# SPDX-License-Identifier: MPL-2.0

"""Find real sleeps in Swift tests. Tests wait on events, bounded timeouts, or injected clocks.

Each `path:real-sleep:count` entry in the allowlist names a file and the exact number of its
genuine sleeps: wall-clock timeout bounds or live-contract probes. A count that differs from the
scan is an error, so a new sleep in a listed file fails until its count is reviewed.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

TEST_SOURCE_ROOT = Path("Tests")
TEST_SLEEP_ALLOWLIST = Path("scripts/test-sleep-allowlist.txt")
RULE = "real-sleep"
# A method call such as `clock.sleep(until:)` is not a real sleep, so the bare C form skips a
# preceding `.` or identifier character.
REAL_SLEEP = re.compile(
    r"\bTask\.sleep\s*\(|\bThread\.sleep\s*\(|\busleep\s*\(|(?<![\w.])sleep\s*\("
)
# A `func sleep(` declaration implements the Clock protocol and waits on nothing.
FAKE_CLOCK_DECLARATION = re.compile(r"\bfunc\s+sleep\s*\(")
# Allowlist entries look like `path:real-sleep:count`; the count is at least 1.
ENTRY = re.compile(rf"([^:]+):{RULE}:([1-9][0-9]*)")
# Masking strings before cutting comments keeps a `//` inside a string from hiding the line.
_STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
_LINE_COMMENT = re.compile(r"//.*")


@dataclass(frozen=True)
class Violation:
    """One line in a Swift test file that calls a real sleep."""

    path: str
    line: int
    text: str


def _code_of(line: str) -> str:
    return _LINE_COMMENT.sub("", _STRING_LITERAL.sub('""', line))


def scan(root: Path) -> list[Violation]:
    """Return every real-sleep call in the Swift test files under `root`, in path and line order."""
    violations: list[Violation] = []
    for path in sorted((root / TEST_SOURCE_ROOT).rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, start=1):
            code = _code_of(line)
            if REAL_SLEEP.search(code) and not FAKE_CLOCK_DECLARATION.search(code):
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
    """Return one message for each unexpected real sleep and each stale or miscounted entry."""
    expected, problems = _load_allowlist(root / TEST_SLEEP_ALLOWLIST)
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

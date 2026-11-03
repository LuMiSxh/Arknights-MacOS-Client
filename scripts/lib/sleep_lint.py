# SPDX-License-Identifier: MPL-2.0

"""Find real sleeps in Swift tests. Tests wait on events, bounded timeouts, or injected clocks.

Each `path:real-sleep` entry in the allowlist names a file whose sleep is genuine: a wall-clock
timeout bound, a live-contract probe, or a fake `Clock`. An entry that matches nothing is an error.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

TEST_SOURCE_ROOT = Path("Tests")
TEST_SLEEP_ALLOWLIST = Path("scripts/test-sleep-allowlist.txt")
RULE = "real-sleep"
# A method call such as `clock.sleep(until:)` is not a real sleep, so the bare C form skips a
# preceding `.` or identifier character.
REAL_SLEEP = re.compile(
    r"\bTask\.sleep\b|\bThread\.sleep\b|\busleep\s*\(|(?<![\w.])sleep\s*\("
)
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
            if REAL_SLEEP.search(_code_of(line)):
                violations.append(Violation(relative, number, line.strip()))
    return violations


def _load_allowlist(path: Path) -> tuple[set[str], list[str]]:
    """Return the allowlisted paths and one problem for each malformed or duplicate line."""
    if not path.is_file():
        return set(), [f"{path.name}: allowlist is missing"]
    entries: set[str] = set()
    problems: list[str] = []
    for number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        file_path, separator, rule = entry.rpartition(":")
        if not separator or not file_path or rule != RULE:
            problems.append(
                f"{path.name}:{number}: expected path:{RULE}, got {entry!r}"
            )
        elif file_path in entries:
            problems.append(f"{path.name}:{number}: duplicate entry {entry}")
        else:
            entries.add(file_path)
    return entries, problems


def check(root: Path) -> list[str]:
    """Return one message for each real sleep not allowlisted, and each stale or malformed entry."""
    allowed, problems = _load_allowlist(root / TEST_SLEEP_ALLOWLIST)
    matched: set[str] = set()
    for violation in scan(root):
        if violation.path in allowed:
            matched.add(violation.path)
        else:
            problems.append(
                f"{violation.path}:{violation.line}: {RULE}: {violation.text}"
            )
    problems.extend(
        f"{path}:{RULE}: allowlist entry matches no violation; remove it"
        for path in sorted(allowed - matched)
    )
    return problems

# SPDX-License-Identifier: MPL-2.0

"""Parse the `path:rule:count` allowlists that the Swift lint scripts share."""

import re
from pathlib import Path

# Allowlist entries look like `path:rule:count`; the count is at least 1.
ENTRY = re.compile(r"([^:]+):([a-z-]+):([1-9][0-9]*)")
# Masking strings before cutting comments keeps a `//` inside a string from hiding the line.
_STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
_LINE_COMMENT = re.compile(r"//.*")


def code_of(line: str) -> str:
    """Return `line` with its string literals masked and its trailing comment removed."""
    return _LINE_COMMENT.sub("", _STRING_LITERAL.sub('""', line))


def load_allowlist(
    path: Path,
    *,
    rules: frozenset[str],
    expected_message: str,
) -> tuple[dict[tuple[str, str], int], list[str]]:
    """Return the expected count for each `(path, rule)` and one problem per malformed line.

    `expected_message` formats `{name}`, `{number}`, `{rule}`, and `{entry}` for an
    entry that is not `path:rule:count` with a count of at least 1 and a known rule.
    """
    if not path.is_file():
        return {}, [f"{path.name}: allowlist is missing"]
    expected: dict[tuple[str, str], int] = {}
    problems: list[str] = []
    rule_hint = next(iter(rules)) if len(rules) == 1 else "rule"
    for number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        parsed = ENTRY.fullmatch(entry)
        if parsed is None or parsed[2] not in rules:
            problems.append(
                expected_message.format(
                    name=path.name, number=number, rule=rule_hint, entry=entry
                )
            )
        elif (parsed[1], parsed[2]) in expected:
            problems.append(f"{path.name}:{number}: duplicate entry {entry}")
        else:
            expected[(parsed[1], parsed[2])] = int(parsed[3])
    return expected, problems

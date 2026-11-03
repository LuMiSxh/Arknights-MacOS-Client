# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path

import pytest
from lib.try_lint import TRY_LINT_ALLOWLIST, check

SOURCE = "Sources/ArknightsGameRuntime/Runtime/Example.swift"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_allowlist(root: Path, *lines: str) -> None:
    write(root / TRY_LINT_ALLOWLIST, "\n".join(lines) + "\n")


@pytest.mark.parametrize(
    "line",
    [
        "let data = try? Data(contentsOf: url)",
        "defer { try? fileManager.removeItem(at: url) }",
        "return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true",
    ],
)
def test_silent_try_without_marker_is_reported(tmp_path: Path, line: str) -> None:
    write(tmp_path / SOURCE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [f"{SOURCE}:1: silent-try: {line}"]


@pytest.mark.parametrize(
    "lines",
    [
        [
            "try? fileManager.removeItem(at: url) // best effort: app-owned temporary file"
        ],
        [
            "// best effort: app-owned temporary file",
            "try? fileManager.removeItem(at: url)",
        ],
    ],
)
def test_best_effort_marker_on_same_or_previous_line_passes(
    tmp_path: Path, lines: list[str]
) -> None:
    write(tmp_path / SOURCE, "\n".join(lines) + "\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_best_effort_marker_two_lines_up_does_not_pass(tmp_path: Path) -> None:
    line = "try? fileManager.removeItem(at: url)"
    write(tmp_path / SOURCE, f"// best effort: too far away\nlet gap = 1\n{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [f"{SOURCE}:3: silent-try: {line}"]


@pytest.mark.parametrize(
    "line",
    [
        "// try? was removed in favor of log.attempt",
        'let label = "try? retries the upload"',
        "let retry = retry?.count",
        "let entry = entry?.name",
        "let value = try fileManager.removeItem(at: url)",
    ],
)
def test_comments_strings_and_non_matches_are_not_flagged(
    tmp_path: Path, line: str
) -> None:
    write(tmp_path / SOURCE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_sources_outside_target_roots_are_not_scanned(tmp_path: Path) -> None:
    write(tmp_path / "Sources/ArknightsCore/Wait.swift", "let x = try? load()\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_allowlisted_silent_try_passes(tmp_path: Path) -> None:
    write(tmp_path / SOURCE, "let x = try? load()\n")
    write_allowlist(
        tmp_path,
        "# Read-only probe; the fallback is safe.",
        f"{SOURCE}:silent-try:1",
    )

    assert check(tmp_path) == []


@pytest.mark.parametrize(("actual", "allowed"), [(2, 1), (1, 2)])
def test_silent_try_count_must_match_allowlist(
    tmp_path: Path, actual: int, allowed: int
) -> None:
    write(tmp_path / SOURCE, "let x = try? load()\n" * actual)
    write_allowlist(tmp_path, f"{SOURCE}:silent-try:{allowed}")

    assert (
        f"{SOURCE}:silent-try: allowlist allows {allowed}, found {actual}; "
        "review and update the count"
    ) in check(tmp_path)


def test_stale_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / SOURCE, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{SOURCE}:silent-try:1")

    assert check(tmp_path) == [
        f"{SOURCE}:silent-try: allowlist entry matches no violation; remove it"
    ]


@pytest.mark.parametrize(
    "entry",
    [
        f"{SOURCE}:silent-trys",
        SOURCE,
        f"{SOURCE}:silent-try",
        f"{SOURCE}:silent-try:0",
    ],
)
def test_malformed_allowlist_entry_fails(tmp_path: Path, entry: str) -> None:
    write(tmp_path / SOURCE, "let x = try? load()\n")
    write_allowlist(tmp_path, entry)

    problems = check(tmp_path)
    assert f"{SOURCE}:1: silent-try: let x = try? load()" in problems
    assert any("expected path:silent-try:count" in problem for problem in problems)


def test_duplicate_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / SOURCE, "let x = try? load()\n")
    write_allowlist(tmp_path, f"{SOURCE}:silent-try:1", f"{SOURCE}:silent-try:1")

    problems = check(tmp_path)
    assert len(problems) == 1
    assert "duplicate entry" in problems[0]

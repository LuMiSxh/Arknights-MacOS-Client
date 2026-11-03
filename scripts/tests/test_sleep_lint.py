# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path

import pytest
from lib.sleep_lint import TEST_SLEEP_ALLOWLIST, check

TEST = "Tests/ArknightsExampleTests/WaitTests.swift"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_allowlist(root: Path, *lines: str) -> None:
    write(root / TEST_SLEEP_ALLOWLIST, "\n".join(lines) + "\n")


@pytest.mark.parametrize(
    "line",
    [
        "try await Task.sleep(for: .milliseconds(50))",
        "try? await Task.sleep(for: retryDelay)",
        "Thread.sleep(forTimeInterval: 0.1)",
        "usleep(100_000)",
        "sleep(1)",
    ],
)
def test_real_sleep_is_reported(tmp_path: Path, line: str) -> None:
    write(tmp_path / TEST, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [f"{TEST}:1: real-sleep: {line}"]


@pytest.mark.parametrize(
    "line",
    [
        "try await clock.sleep(until: deadline, tolerance: nil)",
        "// Task.sleep(for: .seconds(1)) was the old wait",
        'let label = "Task.sleep is retired"',
        "let sleeps = sleepCount",
        "let unsleep = 1",
    ],
)
def test_injected_clock_comments_and_strings_are_not_flagged(
    tmp_path: Path, line: str
) -> None:
    write(tmp_path / TEST, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_sources_outside_tests_are_not_scanned(tmp_path: Path) -> None:
    write(
        tmp_path / "Sources/ArknightsCore/Wait.swift",
        "try await Task.sleep(for: .seconds(1))\n",
    )
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_allowlisted_real_sleep_passes(tmp_path: Path) -> None:
    write(tmp_path / TEST, "try await Task.sleep(for: .seconds(10))\n")
    write_allowlist(
        tmp_path,
        "# Wall-clock timeout bound for the test wait helper.",
        f"{TEST}:real-sleep",
    )

    assert check(tmp_path) == []


def test_fake_clock_declaration_passes_when_allowlisted(tmp_path: Path) -> None:
    write(
        tmp_path / TEST,
        "func sleep(until deadline: Instant, tolerance: Duration?) async throws {}\n",
    )
    write_allowlist(tmp_path, f"{TEST}:real-sleep")

    assert check(tmp_path) == []


def test_stale_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / TEST, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{TEST}:real-sleep")

    assert check(tmp_path) == [
        f"{TEST}:real-sleep: allowlist entry matches no violation; remove it"
    ]


@pytest.mark.parametrize("entry", [f"{TEST}:real-sleeps", f"{TEST}", ":real-sleep"])
def test_malformed_allowlist_entry_fails(tmp_path: Path, entry: str) -> None:
    write(tmp_path / TEST, "try await Task.sleep(for: .seconds(1))\n")
    write_allowlist(tmp_path, entry)

    problems = check(tmp_path)
    assert f"{TEST}:1: real-sleep: try await Task.sleep(for: .seconds(1))" in problems
    assert any("expected path:real-sleep" in problem for problem in problems)


def test_duplicate_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / TEST, "try await Task.sleep(for: .seconds(1))\n")
    write_allowlist(tmp_path, f"{TEST}:real-sleep", f"{TEST}:real-sleep")

    problems = check(tmp_path)
    assert len(problems) == 1
    assert "duplicate entry" in problems[0]

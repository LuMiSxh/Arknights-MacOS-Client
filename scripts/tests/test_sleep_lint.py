# SPDX-License-Identifier: MPL-2.0

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

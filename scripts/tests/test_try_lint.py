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

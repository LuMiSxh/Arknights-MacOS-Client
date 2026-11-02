# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path

import pytest
from lib.design_lint import check
from lib.project_config import DESIGN_LINT_ALLOWLIST

FEATURE = "Sources/ArknightsFeature/Feature.swift"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_allowlist(root: Path, *lines: str) -> None:
    write(root / DESIGN_LINT_ALLOWLIST, "\n".join(lines) + "\n")


def test_violation_reports_file_line_and_rule(tmp_path: Path) -> None:
    write(
        tmp_path / FEATURE,
        "import SwiftUI\n\nlet tint = Color(red: 1, green: 0, blue: 0)\n",
    )
    write_allowlist(tmp_path)

    assert check(tmp_path) == [
        f"{FEATURE}:3: raw-color: let tint = Color(red: 1, green: 0, blue: 0)"
    ]


@pytest.mark.parametrize(
    ("rule", "line"),
    [
        ("raw-color", "let a = Color(.sRGB, red: 1, green: 0, blue: 0)"),
        ("raw-color", "let b = Color.white.opacity(0.2)"),
        ("numeric-radius", "RoundedRectangle(cornerRadius: 12)"),
        ("raw-animation", "value.animation(.easeInOut(duration: 0.2))"),
        ("raw-glass", "view.glassEffect(.regular)"),
        ("system-font", "Text(title).font(.system(size: 14))"),
    ],
)
def test_each_rule_reports_its_literal(tmp_path: Path, rule: str, line: str) -> None:
    write(tmp_path / FEATURE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [f"{FEATURE}:1: {rule}: {line}"]


def test_allowlisted_violation_passes(tmp_path: Path) -> None:
    write(tmp_path / FEATURE, "let tint = Color(red: 1, green: 0, blue: 0)\n")
    write_allowlist(
        tmp_path,
        "# Artwork scrim, to migrate in phase 3.",
        f"{FEATURE}:raw-color",
    )

    assert check(tmp_path) == []


def test_stale_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / FEATURE, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{FEATURE}:raw-color")

    assert check(tmp_path) == [
        f"{FEATURE}:raw-color: allowlist entry matches no violation; remove it"
    ]


def test_unknown_rule_in_allowlist_fails(tmp_path: Path) -> None:
    write(tmp_path / FEATURE, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{FEATURE}:raw-colour")

    problems = check(tmp_path)
    assert len(problems) == 1
    assert "known rule" in problems[0]


@pytest.mark.parametrize(
    "directory",
    ["Sources/ArknightsCore/Shared/UI", "Sources/ArknightsDesignLab"],
)
def test_excluded_directories_are_skipped(tmp_path: Path, directory: str) -> None:
    write(
        tmp_path / directory / "Surface.swift",
        "let tint = Color(red: 1, green: 0, blue: 0)\n",
    )
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


@pytest.mark.parametrize(
    "line",
    [
        "// Color(red: 1, green: 0, blue: 0) was the old tint",
        'let label = "Color(red: 1) is retired"',
        "withAnimation(.linear(duration: 0.2)) { }",
    ],
)
def test_comments_strings_and_linear_are_not_flagged(tmp_path: Path, line: str) -> None:
    write(tmp_path / FEATURE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []

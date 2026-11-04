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
        ("raw-animation", "withAnimation(.linear(duration: 0.2)) { }"),
        ("raw-glass", "view.glassEffect(.regular)"),
        ("system-font", "Text(title).font(.system(size: 14))"),
        ("raw-hue", "let c = Color(hue: 0.5, saturation: 1, brightness: 1)"),
        ("raw-black", "let c = Color.black"),
        ("raw-white-foreground", "Text(title).foregroundStyle(.white)"),
        ("font-weight", "Text(title).fontWeight(.bold)"),
        ("font-weight", "let font = Font.system(weight: .heavy)"),
        ("font-weight", "Text(title).bold()"),
        ("detached-task", "let task = Task.detached { await work() }"),
        ("off-grid-spacing", "HStack(spacing: 6) {"),
        ("off-grid-spacing", ".padding(.horizontal, 14)"),
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
        f"{FEATURE}:raw-color:1",
    )

    assert check(tmp_path) == []


@pytest.mark.parametrize(("actual", "allowed"), [(2, 1), (1, 2)])
def test_violation_count_must_match_allowlist(
    tmp_path: Path, actual: int, allowed: int
) -> None:
    write(tmp_path / FEATURE, "let tint = Color(red: 1, green: 0, blue: 0)\n" * actual)
    write_allowlist(tmp_path, f"{FEATURE}:raw-color:{allowed}")

    assert (
        f"{FEATURE}:raw-color: allowlist allows {allowed}, found {actual}; "
        "review and update the count"
    ) in check(tmp_path)


def test_stale_allowlist_entry_fails(tmp_path: Path) -> None:
    write(tmp_path / FEATURE, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{FEATURE}:raw-color:1")

    assert check(tmp_path) == [
        f"{FEATURE}:raw-color: allowlist entry matches no violation; remove it"
    ]


def test_unknown_rule_in_allowlist_fails(tmp_path: Path) -> None:
    write(tmp_path / FEATURE, "let spacing = 8\n")
    write_allowlist(tmp_path, f"{FEATURE}:raw-colour:1")

    problems = check(tmp_path)
    assert len(problems) == 1
    assert "known rule" in problems[0]


@pytest.mark.parametrize("entry", [f"{FEATURE}:raw-color", f"{FEATURE}:raw-color:0"])
def test_malformed_allowlist_entry_fails(tmp_path: Path, entry: str) -> None:
    write(tmp_path / FEATURE, "let tint = Color(red: 1, green: 0, blue: 0)\n")
    write_allowlist(tmp_path, entry)

    problems = check(tmp_path)
    assert (
        f"{FEATURE}:1: raw-color: let tint = Color(red: 1, green: 0, blue: 0)"
        in problems
    )
    assert any("expected path:rule:count" in problem for problem in problems)


@pytest.mark.parametrize(
    "path",
    [
        "Sources/ArknightsCore/Shared/UI/LauncherTheme.swift",
        "Sources/ArknightsCore/Shared/UI/LauncherVisuals.swift",
        "Sources/ArknightsCore/Shared/UI/LauncherTokens.swift",
        "Sources/ArknightsCore/Shared/UI/AdaptiveGlass.swift",
    ],
)
def test_exempt_token_files_are_skipped(tmp_path: Path, path: str) -> None:
    write(tmp_path / path, "let tint = Color(red: 1, green: 0, blue: 0)\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_other_shared_ui_files_are_scanned(tmp_path: Path) -> None:
    path = "Sources/ArknightsCore/Shared/UI/Components/SkeletonValue.swift"
    write(tmp_path / path, "let tint = Color(red: 1, green: 0, blue: 0)\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [
        f"{path}:1: raw-color: let tint = Color(red: 1, green: 0, blue: 0)"
    ]


def test_design_lab_is_skipped(tmp_path: Path) -> None:
    write(
        tmp_path / "Sources/ArknightsDesignLab/Surface.swift",
        "let tint = Color(red: 1, green: 0, blue: 0)\n",
    )
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


def test_detached_task_is_reported_in_design_lab(tmp_path: Path) -> None:
    path = "Sources/ArknightsDesignLab/Surface.swift"
    write(tmp_path / path, "let task = Task.detached { await work() }\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == [
        f"{path}:1: detached-task: let task = Task.detached {{ await work() }}"
    ]


@pytest.mark.parametrize(
    "line",
    [
        "// Color(red: 1, green: 0, blue: 0) was the old tint",
        'let label = "Color(red: 1) is retired"',
        "withAnimation(.linear) { }",
    ],
)
def test_comments_strings_and_linear_are_not_flagged(tmp_path: Path, line: str) -> None:
    write(tmp_path / FEATURE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []


@pytest.mark.parametrize(
    "line",
    [
        "HStack(spacing: 8) {",
        "VStack(alignment: .leading, spacing: 0) {",
        ".padding(.horizontal, 12)",
        ".padding(2)",
        ".padding(.leading, 1)",
    ],
)
def test_on_grid_and_small_spacing_is_not_flagged(tmp_path: Path, line: str) -> None:
    write(tmp_path / FEATURE, f"{line}\n")
    write_allowlist(tmp_path)

    assert check(tmp_path) == []

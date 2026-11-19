# SPDX-License-Identifier: MPL-2.0

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

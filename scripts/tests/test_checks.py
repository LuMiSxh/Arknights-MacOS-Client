# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import checks
import pytest


def test_handwritten_swift_sources_exclude_generated_catalog_symbols() -> None:
    sources = checks.handwritten_swift_sources()

    assert any(path.name == "L10n.swift" for path in sources)
    assert not any(path.name.startswith("GeneratedStringSymbols_") for path in sources)


def test_workflow_files_find_every_actions_workflow() -> None:
    workflows = checks.workflow_files()

    assert {path.name for path in workflows} == {
        "ci.yml",
        "claude.yml",
        "live-contracts.yml",
        "release.yml",
    }


def test_check_all_runs_every_target_once(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        checks,
        "TARGETS",
        {
            "swift": (
                lambda: calls.append("swift-check"),
                lambda: calls.append("swift-format"),
            ),
            "scripts": (
                lambda: calls.append("scripts-check"),
                lambda: calls.append("scripts-format"),
            ),
        },
    )

    checks.run_mode("check", "all")

    assert calls == ["swift-check", "scripts-check"]


def test_format_single_target_only_calls_that_target(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        checks,
        "TARGETS",
        {
            "swift": (
                lambda: calls.append("swift-check"),
                lambda: calls.append("swift-format"),
            ),
            "shim": (
                lambda: calls.append("shim-check"),
                lambda: calls.append("shim-format"),
            ),
        },
    )

    checks.run_mode("format", "shim")

    assert calls == ["shim-format"]

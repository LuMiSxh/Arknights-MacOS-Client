# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace

import pytest
import swift_tests
from lib.common import ScriptError


def test_unit_and_integration_tests_run_without_network() -> None:
    architectures = ["--arch", "arm64"]

    for name in ("unit", "integration"):
        command = swift_tests.test_command(swift_tests.LEVELS[name], architectures)
        assert command[:3] == [
            "/usr/bin/sandbox-exec",
            "-p",
            swift_tests._NETWORK_DENY_PROFILE,
        ]
        assert "--skip-build" in command
        expression = swift_tests.filter_expression(swift_tests.LEVELS[name].targets)
        assert expression in command


def test_live_contracts_are_the_only_level_allowed_to_use_network() -> None:
    command = swift_tests.test_command(swift_tests.LEVELS["live"], [])

    assert command[0:2] == ["swift", "test"]
    assert "/usr/bin/sandbox-exec" not in command
    assert command[-1] == "^ArknightsClientLiveContractTests\\."


def test_isolated_environment_redirects_user_writes(tmp_path: Path) -> None:
    environment = swift_tests.isolated_environment(
        tmp_path,
        swift_tests.LEVELS["integration"],
    )

    assert environment["HOME"] == str(tmp_path / "home")
    assert environment["CFFIXED_USER_HOME"] == str(tmp_path / "home")
    assert environment["TMPDIR"] == f"{tmp_path / 'tmp'}/"
    assert (
        environment["ARKNIGHTS_CLIENT_INTEGRATION_TESTS"]
        == "RUN_DETERMINISTIC_INTEGRATION_TESTS"
    )


def test_test_count_requires_identifiers_from_the_selected_target() -> None:
    listing = (
        "ArknightsClientTests.UnitSuite/example()\n"
        "ArknightsClientIntegrationTests.Workflow/example()"
    )

    integration = ("ArknightsClientIntegrationTests",)
    assert swift_tests.test_count(listing, integration) == 1
    assert swift_tests.test_count(listing, ("MissingTests",)) == 0


def test_relevant_success_output_filters_known_swift_test_harness_noise() -> None:
    output = """◇ Test run started.
↳ Testing Library Version: 2084
↳ Target Platform: arm64e-apple-macos14.0
2026-09-19 23:47:16.365 swiftpm-testing-helper[73169:408775] CGImageDestinationFinalize failed for output type 'public.tiff'
A warning from the test process that needs attention
✔ Test run with 386 tests in 43 suites passed after 2.485 seconds."""

    assert swift_tests.relevant_success_output(output) == [
        "A warning from the test process that needs attention"
    ]


def test_filter_composes_one_regex_inside_the_selected_target() -> None:
    command = swift_tests.test_command(swift_tests.LEVELS["unit"], [], "GameInstaller")

    assert command.count("--filter") == 1
    assert (
        command[command.index("--filter") + 1]
        == "^(?:ArknightsClientTests|ArknightsInfrastructureTests)\\..*GameInstaller"
    )


def test_filter_counts_only_matching_tests_in_the_selected_target() -> None:
    listing = (
        "ArknightsClientTests.GameInstallerTests/example()\n"
        "ArknightsClientTests.UnitSuite/example()\n"
        "ArknightsClientIntegrationTests.GameInstallerWorkflow/example()"
    )

    unit = ("ArknightsClientTests",)
    integration = ("ArknightsClientIntegrationTests",)

    assert swift_tests.test_count(listing, unit, "GameInstaller") == 1
    assert swift_tests.test_count(listing, integration, "GameInstaller") == 1
    assert swift_tests.test_count(listing, unit, "Missing") == 0


def test_unit_level_covers_every_test_target_except_gated_levels(
    tmp_path: Path,
) -> None:
    package = tmp_path / "Package.swift"
    package.write_text(
        """
        .testTarget(name: "ArknightsClientTests", dependencies: []),
        .testTarget(name: "ArknightsClientIntegrationTests", dependencies: []),
        .testTarget(name: "ArknightsClientLiveContractTests", dependencies: []),
        .testTarget(name: "ModelTests", dependencies: []),
        .target(name: "Helpers", dependencies: []),
        """,
        encoding="utf-8",
    )

    assert swift_tests.unit_targets(package) == ("ArknightsClientTests", "ModelTests")


def test_unit_filter_alternates_every_unit_target() -> None:
    targets = ("ArknightsClientTests", "ModelTests")
    listing = (
        "ArknightsClientTests.Install/example()\n"
        "ModelTests.Install/example()\n"
        "ModelTests.Other/example()\n"
        "ArknightsClientIntegrationTests.Install/example()"
    )

    assert (
        swift_tests.filter_expression(targets, "Install")
        == r"^(?:ArknightsClientTests|ModelTests)\..*Install"
    )
    assert swift_tests.test_count(listing, targets, "Install") == 2
    assert swift_tests.test_count(listing, targets) == 3


def test_run_level_fails_when_filter_matches_no_test(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    listing = "ArknightsClientTests.UnitSuite/example()"
    monkeypatch.setattr(swift_tests, "load_project_configuration", lambda: None)
    monkeypatch.setattr(
        swift_tests, "architecture_arguments", lambda configuration=None: []
    )
    monkeypatch.setattr(swift_tests, "require_command", lambda name: None)
    monkeypatch.setattr(
        swift_tests,
        "run",
        lambda command, **kwargs: SimpleNamespace(stdout=listing, stderr=""),
    )

    with pytest.raises(ScriptError, match="no tests matching"):
        swift_tests.run_level("unit", "Missing")

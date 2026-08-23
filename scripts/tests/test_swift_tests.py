# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path

import swift_tests


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
        assert f"^{swift_tests.LEVELS[name].target}\\." in command


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

    assert swift_tests.test_count(listing, "ArknightsClientIntegrationTests") == 1
    assert swift_tests.test_count(listing, "MissingTests") == 0

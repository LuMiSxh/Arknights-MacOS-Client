# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import os
from pathlib import Path
from types import SimpleNamespace

import localization
import pytest
import swift_tests

SWIFT_TEST_RESOURCE_ENV = "ARKNIGHTS_CLIENT_SWIFT_TESTS"


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


def test_swift_test_catalog_mode_disables_toolchain_symbols(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(localization, "output", lambda *args, **kwargs: "27.0")
    monkeypatch.delenv(SWIFT_TEST_RESOURCE_ENV, raising=False)
    assert localization.toolchain_generates_symbols()

    monkeypatch.setenv(SWIFT_TEST_RESOURCE_ENV, "1")
    assert not localization.toolchain_generates_symbols()


def test_swift_test_run_enables_copy_catalog_mode(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    configuration = SimpleNamespace(
        product=SimpleNamespace(architecture_priority=("arm64",))
    )
    observed: list[str | None] = []

    monkeypatch.delenv(SWIFT_TEST_RESOURCE_ENV, raising=False)
    monkeypatch.setattr(
        swift_tests,
        "load_project_configuration",
        lambda: configuration,
    )
    monkeypatch.setattr(
        swift_tests,
        "prepare_localization",
        lambda **_: observed.append(os.environ.get(SWIFT_TEST_RESOURCE_ENV)),
    )
    monkeypatch.setattr(swift_tests, "require_command", lambda _: None)
    monkeypatch.setattr(swift_tests, "output", lambda *args, **kwargs: str(tmp_path))
    monkeypatch.setattr(swift_tests, "compile_swift_localizations", lambda *args: None)

    def fake_run(command, *, cwd, capture=False, environment=None):
        if capture:
            return SimpleNamespace(stdout="ArknightsClientTests.example()\n")
        if environment is not None:
            observed.append(environment.get(SWIFT_TEST_RESOURCE_ENV))
        return None

    monkeypatch.setattr(swift_tests, "run", fake_run)

    swift_tests.run_level("unit")

    assert observed == ["1", "1"]

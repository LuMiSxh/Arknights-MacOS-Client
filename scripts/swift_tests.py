#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Build and run one explicitly isolated Swift test level."""

from __future__ import annotations

import argparse
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path

from lib.common import PROJECT_DIR, fail, require_command, run, run_main
from lib.console import child_output, success
from lib.project_config import ProjectConfiguration, load_project_configuration

_NETWORK_DENY_PROFILE = "(version 1) (allow default) (deny network*)"
_SWIFT_TEST_TIFF_WARNING = (
    "CGImageDestinationFinalize failed for output type 'public.tiff'"
)
_SWIFT_TEST_HARNESS_PREFIXES = (
    "◇ Test run started.",
    "Testing Library Version:",
    "Target Platform:",
    "✔ Test run with ",
)


@dataclass(frozen=True)
class SwiftTestLevel:
    target: str
    gate: tuple[str, str] | None
    allows_network: bool


LEVELS = {
    "unit": SwiftTestLevel(
        target="ArknightsClientTests",
        gate=None,
        allows_network=False,
    ),
    "integration": SwiftTestLevel(
        target="ArknightsClientIntegrationTests",
        gate=(
            "ARKNIGHTS_CLIENT_INTEGRATION_TESTS",
            "RUN_DETERMINISTIC_INTEGRATION_TESTS",
        ),
        allows_network=False,
    ),
    "live": SwiftTestLevel(
        target="ArknightsClientLiveContractTests",
        gate=(
            "ARKNIGHTS_CLIENT_LIVE_CONTRACT_TESTS",
            "RUN_YOSTAR_PUBLIC_NETWORK_SMOKE_TESTS",
        ),
        allows_network=True,
    ),
}


def architecture_arguments(
    configuration: ProjectConfiguration | None = None,
) -> list[str]:
    configuration = configuration or load_project_configuration()
    return [
        argument
        for architecture in configuration.product.architecture_priority
        for argument in ("--arch", architecture)
    ]


def build_command(architectures: list[str]) -> list[str]:
    return ["swift", "build", "-q", "--build-tests", *architectures]


def test_command(level: SwiftTestLevel, architectures: list[str]) -> list[str]:
    command = [
        "swift",
        "test",
        "-q",
        "--disable-xctest",
        "--skip-build",
        "--disable-sandbox",
        "--disable-automatic-resolution",
        "--filter",
        rf"^{level.target}\.",
        *architectures,
    ]
    if level.allows_network:
        return command
    return [
        "/usr/bin/sandbox-exec",
        "-p",
        _NETWORK_DENY_PROFILE,
        *command,
    ]


def list_command(architectures: list[str]) -> list[str]:
    return [
        "swift",
        "test",
        "list",
        "--skip-build",
        "--disable-sandbox",
        "--disable-automatic-resolution",
        *architectures,
    ]


def test_count(output: str, target: str) -> int:
    prefix = f"{target}."
    return sum(line.startswith(prefix) for line in output.splitlines())


def relevant_success_output(output: str) -> list[str]:
    """Return successful Swift test output that is useful to a human."""
    relevant = []
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        while line.startswith("↳ "):
            line = line[2:].lstrip()
        if (
            line.startswith(_SWIFT_TEST_HARNESS_PREFIXES)
            or _SWIFT_TEST_TIFF_WARNING in line
        ):
            continue
        relevant.append(line)
    return relevant


def isolated_environment(root: Path, level: SwiftTestLevel) -> dict[str, str]:
    home = root / "home"
    temporary = root / "tmp"
    home.mkdir()
    temporary.mkdir()
    environment = os.environ.copy()
    environment.update(
        {
            "HOME": str(home),
            "CFFIXED_USER_HOME": str(home),
            "TMPDIR": f"{temporary}/",
        }
    )
    if level.gate:
        environment[level.gate[0]] = level.gate[1]
    return environment


def run_level(name: str) -> None:
    level = LEVELS[name]
    configuration = load_project_configuration()
    architectures = architecture_arguments(configuration)
    require_command("swift")
    if not level.allows_network:
        require_command("sandbox-exec")

    run(build_command(architectures), cwd=PROJECT_DIR)
    listed_tests = run(
        list_command(architectures), cwd=PROJECT_DIR, capture=True
    ).stdout
    test_total = test_count(listed_tests, level.target)
    if test_total == 0:
        fail(f"Swift {name} test target contains no discoverable tests: {level.target}")

    with tempfile.TemporaryDirectory(prefix=f"arknights-{name}-tests-") as directory:
        result = run(
            test_command(level, architectures),
            cwd=PROJECT_DIR,
            capture=True,
            environment=isolated_environment(Path(directory), level),
        )
    for line in relevant_success_output(f"{result.stdout}\n{result.stderr}"):
        child_output(line)
    suffix = "test" if test_total == 1 else "tests"
    success(f"Swift {name} tests passed ({test_total} {suffix})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("level", choices=LEVELS)
    arguments = parser.parse_args()
    run_level(arguments.level)


if __name__ == "__main__":
    run_main(main)

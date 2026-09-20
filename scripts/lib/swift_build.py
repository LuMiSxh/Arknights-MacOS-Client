# SPDX-License-Identifier: MPL-2.0

"""Build SwiftPM products with the active macOS SDK recorded in Mach-O metadata."""

from __future__ import annotations

import os

from lib.common import output, run
from lib.project_config import ProjectConfiguration


def active_macos_sdk() -> tuple[str, str]:
    """Return the active macOS SDK path and version supplied by Xcode."""
    return (
        output(["xcrun", "--sdk", "macosx", "--show-sdk-path"]),
        output(["xcrun", "--sdk", "macosx", "--show-sdk-version"]),
    )


def swift_build_command(
    project_configuration: ProjectConfiguration,
    build_configuration: str,
    sdk_version: str,
    *,
    show_bin_path: bool = False,
) -> tuple[str, ...]:
    """Build with the package minimum and active SDK as distinct platform versions."""
    arguments = ["swift", "build", "--configuration", build_configuration]
    for architecture in project_configuration.product.architecture_priority:
        arguments.extend(("--arch", architecture))
    arguments.extend(
        (
            "-Xlinker",
            "-platform_version",
            "-Xlinker",
            "macos",
            "-Xlinker",
            project_configuration.package.macos_version,
            "-Xlinker",
            sdk_version,
        )
    )
    if show_bin_path:
        arguments.append("--show-bin-path")
    return tuple(arguments)


def swift_build_environment(sdk_path: str) -> dict[str, str]:
    """Keep SDK lookup and linker metadata aligned for SwiftPM and the linker."""
    environment = os.environ.copy()
    environment["SDKROOT"] = sdk_path
    return environment


def run_swift_build(
    project_configuration: ProjectConfiguration,
    build_configuration: str,
    *,
    show_bin_path: bool = False,
    capture: bool = False,
):
    """Build a SwiftPM product using the active SDK and return the process result."""
    sdk_path, sdk_version = active_macos_sdk()
    return run(
        swift_build_command(
            project_configuration,
            build_configuration,
            sdk_version,
            show_bin_path=show_bin_path,
        ),
        cwd=project_configuration.project_directory,
        capture=capture,
        environment=swift_build_environment(sdk_path),
    )

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["ziglang==0.15.1"]
# ///
# SPDX-License-Identifier: MPL-2.0

"""Build the game compatibility components bundled with the launcher."""

from __future__ import annotations

import argparse
import tempfile
from collections.abc import Callable
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    remove_path,
    run,
    run_main,
    success,
)
from lib.compat_toolchain import compile_windows, validate_macho_x86_64, validate_pe
from lib.console import spinner

BuildResult = tuple[Path, ...]


def require_sources(*paths: Path) -> None:
    for path in paths:
        if not path.is_file():
            fail(f"compatibility source not found: {path}")


def build_vuplex(output_root: Path) -> BuildResult:
    source_directory = PROJECT_DIR / "RuntimeSupport/Vuplex"
    shim_source = source_directory / "VuplexShim.c"
    userenv_source = source_directory / "UserenvCompat.c"
    require_sources(shim_source, userenv_source)

    destination = output_root / "Vuplex"
    destination.mkdir(parents=True, exist_ok=True)
    shim_output = destination / "Vuplex WebView.vuplex"
    userenv_output = destination / "userenv.dll"
    with tempfile.TemporaryDirectory(prefix=".vuplex-build.", dir=destination) as name:
        temporary = Path(name)
        temporary_shim = temporary / shim_output.name
        temporary_userenv = temporary / userenv_output.name
        with spinner("Compiling the Vuplex wrapper"):
            compile_windows(
                shim_source,
                temporary_shim,
                "-Wl,/subsystem:windows",
                "-lshell32",
            )
        with spinner("Compiling the Vuplex userenv library"):
            compile_windows(
                userenv_source,
                temporary_userenv,
                "-shared",
                "-ladvapi32",
            )
        validate_pe(temporary_shim, dll=False)
        validate_pe(temporary_userenv, dll=True)
        remove_path(shim_output)
        remove_path(userenv_output)
        temporary_shim.replace(shim_output)
        temporary_userenv.replace(userenv_output)
    return shim_output, userenv_output


def build_platform_process(output_root: Path) -> BuildResult:
    source_directory = PROJECT_DIR / "RuntimeSupport/PlatformProcess"
    shim_source = source_directory / "PlatformProcessShim.c"
    bridge_source = source_directory / "PlatformProcessWindowBridge.m"
    require_sources(shim_source, bridge_source)

    destination = output_root / "PlatformProcess"
    destination.mkdir(parents=True, exist_ok=True)
    shim_output = destination / "PlatformProcess.exe"
    bridge_output = destination / "PlatformProcessWindowBridge.dylib"
    with tempfile.TemporaryDirectory(
        prefix=".platform-process-build.", dir=destination
    ) as name:
        temporary = Path(name)
        temporary_shim = temporary / shim_output.name
        temporary_bridge = temporary / bridge_output.name
        with spinner("Compiling the PlatformProcess wrapper"):
            compile_windows(
                shim_source,
                temporary_shim,
                "-municode",
                "-Wl,/subsystem:windows",
                "-lshell32",
            )
        with spinner("Compiling the PlatformProcess AppKit bridge"):
            run(
                [
                    "xcrun",
                    "clang",
                    "-arch",
                    "x86_64",
                    "-O2",
                    "-fobjc-arc",
                    "-dynamiclib",
                    "-framework",
                    "AppKit",
                    "-framework",
                    "QuartzCore",
                    bridge_source,
                    "-o",
                    temporary_bridge,
                ]
            )
        validate_pe(temporary_shim, dll=False)
        validate_macho_x86_64(temporary_bridge)
        remove_path(shim_output)
        remove_path(bridge_output)
        temporary_shim.replace(shim_output)
        temporary_bridge.replace(bridge_output)
    return shim_output, bridge_output


def build_game_icon(output_root: Path) -> BuildResult:
    source = PROJECT_DIR / "RuntimeSupport/GameIcon/GameIconBridge.m"
    require_sources(source)

    destination = output_root / "GameIcon"
    destination.mkdir(parents=True, exist_ok=True)
    output_path = destination / "GameIconBridge.dylib"
    with tempfile.TemporaryDirectory(
        prefix=".game-icon-build.", dir=destination
    ) as name:
        temporary_output = Path(name) / output_path.name
        with spinner("Compiling the game icon bridge"):
            run(
                [
                    "xcrun",
                    "clang",
                    "-arch",
                    "x86_64",
                    "-O2",
                    "-dynamiclib",
                    "-lobjc",
                    source,
                    "-o",
                    temporary_output,
                ]
            )
        validate_macho_x86_64(temporary_output)
        remove_path(output_path)
        temporary_output.replace(output_path)
    return (output_path,)


BUILDERS: dict[str, Callable[[Path], BuildResult]] = {
    "vuplex": build_vuplex,
    "platform-process": build_platform_process,
    "game-icon": build_game_icon,
}


def build(output_root: Path, components: tuple[str, ...]) -> BuildResult:
    output_root = output_root.resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    built: list[Path] = []
    for component in components:
        built.extend(BUILDERS[component](output_root))
    return tuple(built)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--component",
        action="append",
        choices=tuple(BUILDERS),
        dest="components",
        help="Build one component; repeat for multiple components (default: all).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=BUILD_DIR / "helpers",
    )
    arguments = parser.parse_args()
    components = tuple(arguments.components or BUILDERS)
    for path in build(arguments.output, components):
        success(f"Built {path.relative_to(PROJECT_DIR)}")


if __name__ == "__main__":
    run_main(main)

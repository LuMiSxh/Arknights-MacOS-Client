#!/usr/bin/env -S uv run --locked --no-dev --group packaging
# SPDX-License-Identifier: MPL-2.0

"""Build the game compatibility components bundled with the launcher."""

from __future__ import annotations

import argparse
import struct
import sys
import tempfile
import tomllib
from pathlib import Path
from typing import Any

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    output,
    remove_path,
    run,
    run_main,
)
from lib.console import spinner, success

BuildResult = tuple[Path, ...]
MANIFEST = PROJECT_DIR / "RuntimeSupport/support.toml"


def compile_windows(source: Path, destination: Path, *arguments: str) -> None:
    run(
        [
            sys.executable,
            "-m",
            "ziglang",
            "cc",
            "-target",
            "x86_64-windows-gnu",
            "-O2",
            source,
            *arguments,
            "-o",
            destination,
        ]
    )


def validate_pe(path: Path, *, dll: bool) -> None:
    data = path.read_bytes()
    if len(data) < 0x40 or data[:2] != b"MZ":
        fail(f"expected a Windows PE file: {path}")
    header_offset = struct.unpack_from("<I", data, 0x3C)[0]
    valid = (
        header_offset + 26 <= len(data)
        and data[header_offset : header_offset + 4] == b"PE\0\0"
        and struct.unpack_from("<H", data, header_offset + 4)[0] == 0x8664
        and struct.unpack_from("<H", data, header_offset + 24)[0] == 0x20B
        and bool(struct.unpack_from("<H", data, header_offset + 22)[0] & 0x2000) is dll
    )
    if not valid:
        kind = "DLL" if dll else "executable"
        fail(f"expected a PE32+ x86-64 {kind}: {path}")


def validate_macho_x86_64(path: Path) -> None:
    architectures = output(["lipo", "-archs", path]).split()
    if architectures != ["x86_64"]:
        fail(f"expected an x86-64 Mach-O file: {path}")


def load_components() -> list[dict[str, Any]]:
    try:
        with MANIFEST.open("rb") as file:
            return tomllib.load(file)["components"]
    except (OSError, KeyError, tomllib.TOMLDecodeError) as error:
        fail(f"unable to read compatibility manifest: {error}")


def compile_artifact(source: Path, destination: Path, artifact: dict[str, Any]) -> None:
    kind = artifact["kind"]
    arguments = artifact.get("arguments", [])
    if kind.startswith("windows-"):
        shared = kind == "windows-library"
        if not shared and kind != "windows-executable":
            fail(f"unknown compatibility artifact kind: {kind}")
        compile_windows(
            source,
            destination,
            *("-shared",) if shared else (),
            *arguments,
        )
        validate_pe(destination, dll=shared)
        return
    if kind != "macos-library":
        fail(f"unknown compatibility artifact kind: {kind}")
    frameworks = [
        argument
        for framework in artifact.get("frameworks", [])
        for argument in ("-framework", framework)
    ]
    run(
        [
            "xcrun",
            "clang",
            "-arch",
            "x86_64",
            "-O2",
            "-dynamiclib",
            *arguments,
            *frameworks,
            source,
            "-o",
            destination,
        ]
    )
    validate_macho_x86_64(destination)


def build_component(output_root: Path, component: dict[str, Any]) -> BuildResult:
    directory = component["directory"]
    source_directory = PROJECT_DIR / "RuntimeSupport" / directory
    destination = output_root / directory
    destination.mkdir(parents=True, exist_ok=True)
    built: list[Path] = []
    with tempfile.TemporaryDirectory(
        prefix=f".{component['name']}-build.", dir=destination
    ) as name:
        temporary = Path(name)
        staged: list[tuple[Path, Path]] = []
        for artifact in component["artifacts"]:
            source = source_directory / artifact["source"]
            output_path = destination / artifact["output"]
            temporary_output = temporary / output_path.name
            if not source.is_file():
                fail(f"compatibility source not found: {source}")
            with spinner(f"Compiling {artifact['output']}"):
                compile_artifact(source, temporary_output, artifact)
            staged.append((temporary_output, output_path))
            built.append(output_path)
        for temporary_output, output_path in staged:
            remove_path(output_path)
            temporary_output.replace(output_path)
    return tuple(built)


def build(output_root: Path, components: tuple[str, ...] | None = None) -> BuildResult:
    output_root = output_root.resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    available = {component["name"]: component for component in load_components()}
    built: list[Path] = []
    for name in tuple(available) if components is None else components:
        built.extend(build_component(output_root, available[name]))
    return tuple(built)


def main() -> None:
    component_names = tuple(component["name"] for component in load_components())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--component",
        action="append",
        choices=component_names,
        dest="components",
        help="Build one component; repeat for multiple components (default: all).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=BUILD_DIR / "helpers",
    )
    arguments = parser.parse_args()
    components = tuple(arguments.components) if arguments.components else None
    for path in build(arguments.output, components):
        success(f"Built {path.relative_to(PROJECT_DIR)}")


if __name__ == "__main__":
    run_main(main)

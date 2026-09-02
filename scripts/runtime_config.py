#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Read and validate the pinned runtime configuration."""

from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

from lib.common import fail, run_main

SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
MAXIMUM_RUNTIME_ARCHIVE_BYTES = 600 * 1_024 * 1_024


@dataclass(frozen=True)
class RuntimeSymlink:
    path: PurePosixPath
    target: PurePosixPath


@dataclass(frozen=True)
class DXMTLayout:
    payload_directory: PurePosixPath
    destinations: tuple[tuple[str, str], ...]
    libraries: tuple[str, ...]


@dataclass(frozen=True)
class RuntimeLayout:
    archive_wine_directory: PurePosixPath
    archive_dxmt_directory: PurePosixPath
    executables: tuple[PurePosixPath, ...]
    required_files: tuple[PurePosixPath, ...]
    mac_driver: PurePosixPath
    launcher: RuntimeSymlink
    dxmt: DXMTLayout

    @property
    def required_regular_files(self) -> tuple[PurePosixPath, ...]:
        dxmt_files = tuple(
            self.dxmt.payload_directory / architecture / library
            for architecture, _ in self.dxmt.destinations
            for library in self.dxmt.libraries
        )
        return (*self.required_files, self.mac_driver, *dxmt_files)

    @property
    def required_paths(self) -> tuple[PurePosixPath, ...]:
        return (*self.executables, *self.required_regular_files)


@dataclass(frozen=True)
class RuntimeConfiguration:
    raw: dict[str, Any]
    layout: RuntimeLayout

    @property
    def runtime_url(self) -> str:
        return str(nested_value(self.raw, "runtime.url"))

    @property
    def runtime_sha256(self) -> str:
        return str(nested_value(self.raw, "runtime.sha256"))


def runtime_is_valid(directory: Path, layout: RuntimeLayout) -> bool:
    try:
        root = directory.resolve(strict=True)
        if not all(
            _contained_file(root, directory / path)
            and os.access(directory / path, os.X_OK)
            for path in layout.executables
        ):
            return False
        if not all(
            not (directory / path).is_symlink()
            and _contained_file(root, directory / path)
            for path in layout.required_regular_files
        ):
            return False
        launcher = directory / layout.launcher.path
        return (
            launcher.is_symlink()
            and launcher.readlink() == Path(layout.launcher.target)
            and launcher.resolve(strict=True).is_relative_to(root)
        )
    except OSError:
        return False


def _contained_file(root: Path, path: Path) -> bool:
    return path.is_file() and path.resolve(strict=True).is_relative_to(root)


def read_config(config: Path) -> dict[str, Any]:
    try:
        value: Any = json.loads(config.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"unable to read {config}: {error}")
    if not isinstance(value, dict):
        fail("runtime configuration root must be an object")
    return value


def nested_value(config: dict[str, Any], key: str) -> Any:
    value: Any = config
    for component in key.split("."):
        if not isinstance(value, dict) or component not in value:
            fail(f"runtime configuration has no value for {key}")
        value = value[component]
    return value


def read_value(config: Path, key: str) -> str:
    value = nested_value(read_config(config), key)
    if not isinstance(value, (str, int, float, bool)):
        fail(f"runtime configuration value is not scalar: {key}")
    return str(value).lower() if isinstance(value, bool) else str(value)


def _mapping(config: dict[str, Any], key: str) -> dict[str, Any]:
    value = nested_value(config, key)
    if not isinstance(value, dict) or not value:
        fail(f"runtime configuration value must be a non-empty object: {key}")
    return value


def _string(config: dict[str, Any], key: str) -> str:
    value = nested_value(config, key)
    if not isinstance(value, str) or not value:
        fail(f"runtime configuration value must be a non-empty string: {key}")
    return value


def _relative_path(config: dict[str, Any], key: str) -> PurePosixPath:
    return _safe_list_path(_string(config, key), key)


def _string_list(config: dict[str, Any], key: str) -> tuple[str, ...]:
    value = nested_value(config, key)
    if (
        not isinstance(value, list)
        or not value
        or not all(isinstance(item, str) and item for item in value)
    ):
        fail(f"runtime configuration value must be a non-empty string array: {key}")
    if len(value) != len(set(value)):
        fail(f"runtime configuration array contains duplicates: {key}")
    return tuple(value)


def _validate_download(name: str, value: dict[str, Any]) -> None:
    for field in ("url", "sha256"):
        field_value = value.get(field)
        if not isinstance(field_value, str) or not field_value:
            fail(
                f"runtime configuration value must be a non-empty string: {name}.{field}"
            )
    if not value["url"].startswith("https://"):
        fail(f"runtime configuration URL must use HTTPS: {name}.url")
    if not SHA256_PATTERN.fullmatch(value["sha256"]):
        fail(f"runtime configuration checksum must be lowercase SHA-256: {name}.sha256")


def _validate_components(config: dict[str, Any]) -> None:
    components = _mapping(config, "components")
    provenance = _mapping(config, "provenance")
    if not all(isinstance(name, str) and name for name in components):
        fail("runtime component names must be non-empty strings")
    for name, version in components.items():
        if not isinstance(version, str) or not version:
            fail(f"runtime component version must be a non-empty string: {name}")
    source_names = {
        key.removesuffix("Repository")
        for key in provenance
        if isinstance(key, str) and key.endswith("Repository")
    }
    commit_names = {
        key.removesuffix("Commit")
        for key in provenance
        if isinstance(key, str) and key.endswith("Commit")
    }
    if source_names != commit_names:
        fail("runtime provenance repository and commit entries must be paired")
    required_sources = {"build", *components}
    if not required_sources <= source_names:
        missing = ", ".join(sorted(required_sources - source_names))
        fail(f"runtime provenance is missing component sources: {missing}")
    for name in source_names:
        repository = provenance[f"{name}Repository"]
        commit = provenance[f"{name}Commit"]
        if not isinstance(repository, str) or not repository.startswith("https://"):
            fail(f"runtime provenance repository must use HTTPS: {name}")
        if not isinstance(commit, str) or not COMMIT_PATTERN.fullmatch(commit):
            fail(f"runtime provenance commit must be a lowercase Git commit: {name}")


def _read_layout(config: dict[str, Any]) -> RuntimeLayout:
    executables = tuple(
        _safe_list_path(value, "interface.executables")
        for value in _string_list(config, "interface.executables")
    )
    required_files = tuple(
        _safe_list_path(value, "interface.requiredFiles")
        for value in _string_list(config, "interface.requiredFiles")
    )
    destination_values = _mapping(config, "interface.dxmt.destinations")
    destinations: list[tuple[str, str]] = []
    for architecture, windows_directory in destination_values.items():
        if not _safe_component(architecture) or not _safe_component(windows_directory):
            fail("runtime DXMT destinations must use safe path components")
        destinations.append((architecture, windows_directory))
    libraries = _string_list(config, "interface.dxmt.libraries")
    if not all(_safe_component(library) for library in libraries):
        fail("runtime DXMT libraries must use file names without path separators")
    launcher_target = _relative_path(config, "interface.launcher.target")
    if len(launcher_target.parts) != 1:
        fail("runtime launcher target must be relative to its containing directory")
    return RuntimeLayout(
        archive_wine_directory=_relative_path(
            config, "interface.archive.wineDirectory"
        ),
        archive_dxmt_directory=_relative_path(
            config, "interface.archive.dxmtDirectory"
        ),
        executables=executables,
        required_files=required_files,
        mac_driver=_relative_path(config, "interface.macDriver"),
        launcher=RuntimeSymlink(
            path=_relative_path(config, "interface.launcher.path"),
            target=launcher_target,
        ),
        dxmt=DXMTLayout(
            payload_directory=_relative_path(config, "interface.dxmt.payloadDirectory"),
            destinations=tuple(destinations),
            libraries=libraries,
        ),
    )


def _safe_component(value: object) -> bool:
    return (
        isinstance(value, str)
        and bool(value)
        and PurePosixPath(value).name == value
        and value not in (".", "..")
    )


def _safe_list_path(value: str, key: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if path.is_absolute() or any(
        component in ("", ".", "..") for component in path.parts
    ):
        fail(f"runtime configuration path must be safe and relative: {key}")
    return path


def load_runtime_config(config_path: Path) -> RuntimeConfiguration:
    config = read_config(config_path)
    if nested_value(config, "schemaVersion") != 2:
        fail("runtime configuration schemaVersion must be 2")
    prefix_revision = nested_value(config, "prefixRevision")
    if (
        not isinstance(prefix_revision, int)
        or isinstance(prefix_revision, bool)
        or prefix_revision < 1
    ):
        fail("runtime configuration prefixRevision must be a positive integer")
    for name in ("runtime", "buildRecipe"):
        value = _mapping(config, name)
        _validate_download(name, value)
    _string(config, "runtime.name")
    _validate_components(config)
    return RuntimeConfiguration(raw=config, layout=_read_layout(config))


def validate_config(config_path: Path) -> None:
    load_runtime_config(config_path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("config", type=Path)
    parser.add_argument("key", nargs="?")
    arguments = parser.parse_args()
    if arguments.validate:
        if arguments.key is not None:
            parser.error("a key cannot be used with --validate")
        validate_config(arguments.config)
        return
    if arguments.key is None:
        parser.error("a key is required unless --validate is used")
    print(read_value(arguments.config, arguments.key))


if __name__ == "__main__":
    run_main(main)

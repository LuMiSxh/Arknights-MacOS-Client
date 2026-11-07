# SPDX-License-Identifier: MPL-2.0

"""Load and validate the pinned runtime configuration."""

from __future__ import annotations

import json
import os
import re
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

from lib.common import BUILD_DIR, PROJECT_DIR, fail
from lib.console import warning

SCHEMA_VERSION = 3
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
MINIMUM_MACOS_PATTERN = re.compile(r"^[0-9]+\.[0-9]+(?:\.[0-9]+)?$")
# Release architectures and the Wine module directory each one uses.
RUNTIME_ARCHITECTURES = {"x86": "x86_64", "arm": "aarch64"}
MAXIMUM_RUNTIME_ARCHIVE_BYTES = 600 * 1_024 * 1_024
PREPARED_REVISION_FILE = ".arknights-runtime-archive-sha256"


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
class RuntimeFeatures:
    hardware_cursor: bool
    metal_fx_spatial_upscaling: bool
    native_fullscreen_space: bool

    def mapping(self) -> dict[str, bool]:
        return {
            "hardwareCursor": self.hardware_cursor,
            "metalFXSpatialUpscaling": self.metal_fx_spatial_upscaling,
            "nativeFullscreenSpace": self.native_fullscreen_space,
        }


@dataclass(frozen=True)
class RuntimeLayout:
    archive_wine_directory: PurePosixPath
    archive_dxmt_directory: PurePosixPath
    features: RuntimeFeatures
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
class PinnedRuntime:
    """One runtime archive pinned for one lane.

    A lane that the release task has not published yet has an empty URL, an empty
    checksum, and a zero size. The launcher hides that lane until a client release
    pins it.
    """

    name: str
    version: str
    url: str
    sha256: str
    size_bytes: int

    @property
    def is_available(self) -> bool:
        return bool(self.url) and bool(self.sha256) and self.size_bytes > 0


@dataclass(frozen=True)
class RuntimeLaneConfiguration:
    """The pinned runtime, interface, and provenance of one architecture."""

    name: str
    minimum_macos: str
    prefix_revision: int
    runtime: PinnedRuntime
    layout: RuntimeLayout
    components: Mapping[str, str]
    provenance: Mapping[str, Any]


@dataclass(frozen=True)
class RuntimeConfiguration:
    raw: dict[str, Any]
    lanes: Mapping[str, RuntimeLaneConfiguration]
    architecture: str
    prefix_revision: int

    def lane(self, architecture: str) -> RuntimeLaneConfiguration:
        """Return the configuration of one explicitly named lane."""
        if architecture not in RUNTIME_ARCHITECTURES:
            fail(
                "runtime configuration architecture must be "
                + " or ".join(RUNTIME_ARCHITECTURES)
            )
        lane = self.lanes.get(architecture)
        if lane is None:
            fail(f"runtime configuration has no {architecture} lane")
        return lane

    def for_architecture(self, architecture: str) -> RuntimeLayout:
        """Return the interface a local runtime of one architecture must match."""
        return self.lane(architecture).layout

    @property
    def selected(self) -> RuntimeLaneConfiguration:
        """Return the lane that the bridge fallback names."""
        return self.lane(self.architecture)

    @property
    def selected_layout(self) -> RuntimeLayout:
        """Return the interface of the bridge fallback lane."""
        return self.selected.layout

    @property
    def runtime_url(self) -> str:
        return self.selected.runtime.url

    @property
    def runtime_sha256(self) -> str:
        return self.selected.runtime.sha256

    @property
    def runtime_size_bytes(self) -> int:
        return self.selected.runtime.size_bytes


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


def prepared_runtime(root: Path, architecture: str | None = None) -> Path | None:
    """Return the prepared runtime of one lane if it matches that lane's pin."""
    config = load_runtime_config(root / "runtime.json")
    lane = config.lane(architecture or config.architecture)
    if not lane.runtime.is_available:
        warning(f"the {lane.name} runtime has no published pin yet")
        return None
    directory = root / BUILD_DIR.relative_to(PROJECT_DIR) / f"runtime-{lane.name}"
    if not directory.is_dir():
        return None
    revision = directory / PREPARED_REVISION_FILE
    if (
        revision.is_file()
        and revision.read_text(encoding="utf-8").strip() == lane.runtime.sha256
        and runtime_is_valid(directory, lane.layout)
    ):
        return directory
    warning(
        f"{directory} does not match runtime.json; "
        f"run just runtime download --architecture {lane.name}"
    )
    return None


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


def _optional_mapping(config: dict[str, Any], key: str) -> dict[str, Any]:
    value = nested_value(config, key)
    if value is None:
        return {}
    if not isinstance(value, dict):
        fail(f"runtime configuration value must be an object: {key}")
    return value


def _mapping(config: dict[str, Any], key: str) -> dict[str, Any]:
    value = nested_value(config, key)
    if not isinstance(value, dict) or not value:
        fail(f"runtime configuration value must be a non-empty object: {key}")
    return value


def _string(config: dict[str, Any], key: str, *, allow_empty: bool = False) -> str:
    value = nested_value(config, key)
    if not isinstance(value, str) or (not allow_empty and not value):
        fail(f"runtime configuration value must be a non-empty string: {key}")
    return value


def _positive_integer(config: dict[str, Any], key: str) -> int:
    value = nested_value(config, key)
    if not isinstance(value, int) or isinstance(value, bool) or value < 1:
        fail(f"runtime configuration value must be a positive integer: {key}")
    return value


def _non_negative_integer(config: dict[str, Any], key: str) -> int:
    value = nested_value(config, key)
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        fail(f"runtime configuration value must be a non-negative integer: {key}")
    return value


def _relative_path(config: dict[str, Any], key: str) -> PurePosixPath:
    return _safe_list_path(_string(config, key), key)


def _features(config: dict[str, Any], key: str) -> RuntimeFeatures:
    value = nested_value(config, key)
    names = ("hardwareCursor", "metalFXSpatialUpscaling", "nativeFullscreenSpace")
    if not isinstance(value, dict) or set(value) != set(names):
        fail(
            f"runtime configuration features must name the three known features: {key}"
        )
    for name in names:
        if not isinstance(value[name], bool):
            fail(f"runtime configuration feature must be a boolean: {key}.{name}")
    return RuntimeFeatures(
        hardware_cursor=value["hardwareCursor"],
        metal_fx_spatial_upscaling=value["metalFXSpatialUpscaling"],
        native_fullscreen_space=value["nativeFullscreenSpace"],
    )


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


def _read_pin(config: dict[str, Any], key: str) -> PinnedRuntime:
    name = _string(config, f"{key}.name")
    version = _string(config, f"{key}.version")
    url = _string(config, f"{key}.url", allow_empty=True)
    checksum = _string(config, f"{key}.sha256", allow_empty=True)
    size_bytes = _non_negative_integer(config, f"{key}.sizeBytes")
    if not _safe_component(version):
        fail(f"runtime configuration version must be a path component: {key}.version")
    if url and not url.startswith("https://"):
        fail(f"runtime configuration URL must use HTTPS: {key}.url")
    if checksum and not SHA256_PATTERN.fullmatch(checksum):
        fail(f"runtime configuration checksum must be lowercase SHA-256: {key}.sha256")
    if size_bytes > MAXIMUM_RUNTIME_ARCHIVE_BYTES:
        fail(f"runtime configuration archive is larger than the download limit: {key}")
    if (url or checksum or size_bytes) and not (url and checksum and size_bytes > 0):
        fail(f"runtime configuration pin must be complete or empty: {key}")
    return PinnedRuntime(
        name=name,
        version=version,
        url=url,
        sha256=checksum,
        size_bytes=size_bytes,
    )


def _validate_components(
    config: dict[str, Any], prefix: str
) -> tuple[dict[str, str], dict[str, Any]]:
    components = _optional_mapping(config, f"{prefix}.components")
    provenance = _optional_mapping(config, f"{prefix}.provenance")
    if not components and not provenance:
        return {}, {}
    if components and not provenance:
        fail(f"runtime configuration provenance is required: {prefix}.provenance")
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
    return dict(components), dict(provenance)


def _read_layout(config: dict[str, Any], prefix: str = "interface") -> RuntimeLayout:
    executables = tuple(
        _safe_list_path(value, f"{prefix}.executables")
        for value in _string_list(config, f"{prefix}.executables")
    )
    required_files = tuple(
        _safe_list_path(value, f"{prefix}.requiredFiles")
        for value in _string_list(config, f"{prefix}.requiredFiles")
    )
    destination_values = _mapping(config, f"{prefix}.dxmt.destinations")
    destinations: list[tuple[str, str]] = []
    for architecture, windows_directory in destination_values.items():
        if not _safe_component(architecture) or not _safe_component(windows_directory):
            fail("runtime DXMT destinations must use safe path components")
        destinations.append((architecture, windows_directory))
    libraries = _string_list(config, f"{prefix}.dxmt.libraries")
    if not all(_safe_component(library) for library in libraries):
        fail("runtime DXMT libraries must use file names without path separators")
    launcher_target = _relative_path(config, f"{prefix}.launcher.target")
    if len(launcher_target.parts) != 1:
        fail("runtime launcher target must be relative to its containing directory")
    return RuntimeLayout(
        archive_wine_directory=_relative_path(
            config, f"{prefix}.archive.wineDirectory"
        ),
        archive_dxmt_directory=_relative_path(
            config, f"{prefix}.archive.dxmtDirectory"
        ),
        features=_features(config, f"{prefix}.features"),
        executables=executables,
        required_files=required_files,
        mac_driver=_relative_path(config, f"{prefix}.macDriver"),
        launcher=RuntimeSymlink(
            path=_relative_path(config, f"{prefix}.launcher.path"),
            target=launcher_target,
        ),
        dxmt=DXMTLayout(
            payload_directory=_relative_path(config, f"{prefix}.dxmt.payloadDirectory"),
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


def _read_lane(config: dict[str, Any], name: str) -> RuntimeLaneConfiguration:
    prefix = f"lanes.{name}"
    minimum_macos = _string(config, f"{prefix}.minimumMacOS")
    if MINIMUM_MACOS_PATTERN.fullmatch(minimum_macos) is None:
        fail(f"runtime configuration minimumMacOS must be a version: {prefix}")
    components, provenance = _validate_components(config, prefix)
    return RuntimeLaneConfiguration(
        name=name,
        minimum_macos=minimum_macos,
        prefix_revision=_positive_integer(config, f"{prefix}.prefixRevision"),
        runtime=_read_pin(config, f"{prefix}.runtime"),
        layout=_read_layout(config, f"{prefix}.interface"),
        components=components,
        provenance=provenance,
    )


def load_runtime_config(config_path: Path) -> RuntimeConfiguration:
    config = read_config(config_path)
    schema_version = nested_value(config, "schemaVersion")
    if schema_version != SCHEMA_VERSION:
        fail(f"runtime configuration schemaVersion must be {SCHEMA_VERSION}")
    prefix_revision = _positive_integer(config, "prefixRevision")
    architecture = _string(config, "architecture")
    if architecture not in RUNTIME_ARCHITECTURES:
        fail("runtime configuration architecture must be x86 or arm")
    lane_values = _mapping(config, "lanes")
    unknown = sorted(set(lane_values) - set(RUNTIME_ARCHITECTURES))
    if unknown:
        fail(f"runtime configuration has unknown lanes: {', '.join(unknown)}")
    for forbidden in ("armInterface", "runtime", "buildRecipe", "interface"):
        if forbidden in config:
            fail(
                "runtime configuration must keep the runtime contract in lanes: "
                f"remove {forbidden}"
            )
    lanes = {
        name: _read_lane(config, name)
        for name in RUNTIME_ARCHITECTURES
        if name in lane_values
    }
    if architecture not in lanes:
        fail(f"runtime configuration architecture names a missing lane: {architecture}")
    return RuntimeConfiguration(
        raw=config,
        lanes=lanes,
        architecture=architecture,
        prefix_revision=prefix_revision,
    )

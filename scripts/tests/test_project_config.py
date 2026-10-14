# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
from pathlib import Path

import pytest
from lib.common import ScriptError
from lib.project_config import ProjectConfiguration, load_project_configuration


def plist(*, executable: str = "Client") -> dict[str, object]:
    return {
        "CFBundleDisplayName": "Example Client",
        "CFBundleName": "Example Client",
        "CFBundleExecutable": executable,
        "CFBundleIdentifier": "example.client",
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleIconName": "AppIcon",
        "CFBundleIconFile": "AppIcon",
        "LSMinimumSystemVersion": "15.0",
        "LSArchitecturePriority": ["arm64"],
    }


def package_dump(
    *,
    name: str = "Client",
    resources: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    return {
        "dependencies": [],
        "name": name,
        "platforms": [{"platformName": "macos", "version": "15.0"}],
        "products": [{"name": name, "type": {"executable": {}}, "targets": [name]}],
        "targets": [
            {
                "name": name,
                "type": "executable",
                "path": f"Sources/{name}",
                "resources": resources
                or [
                    {"path": "Resources/Icon.png", "rule": {"copy": {}}},
                ],
            }
        ],
    }


def load_configuration(
    root: Path, plist_value: dict[str, object], dump_value: dict[str, object]
) -> ProjectConfiguration:
    info = root / "Resources/Info.plist"
    info.parent.mkdir()
    with info.open("wb") as file:
        plistlib.dump(plist_value, file)
    return load_project_configuration(root, dump_value)


def test_derives_paths_from_manifest_and_plist(tmp_path: Path) -> None:
    configuration = load_configuration(tmp_path, plist(), package_dump())

    assert configuration.app_bundle_name == "Example Client.app"
    assert configuration.release_asset_stem == "Example.Client"
    assert configuration.dmg_name == "Example.Client.dmg"
    assert configuration.sparkle_update_name == "Example.Client.tar.xz"
    assert configuration.copied_resource_source_paths == (
        configuration.resource_target_directory / "Resources/Icon.png",
    )


def test_renamed_target_and_resources_are_derived_automatically(
    tmp_path: Path,
) -> None:
    resources = [
        {"path": "Assets/Brand.png", "rule": {"copy": {}}},
        {"path": "Assets/WallpaperTags.json", "rule": {"copy": {}}},
    ]
    configuration = load_configuration(
        tmp_path,
        plist(executable="Renamed"),
        package_dump(name="Renamed", resources=resources),
    )

    assert configuration.copied_resource_source_paths == (
        configuration.resource_target_directory / "Assets/Brand.png",
        configuration.resource_target_directory / "Assets/WallpaperTags.json",
    )


@pytest.mark.parametrize(
    ("plist_value", "dump_value"),
    [
        pytest.param(plist(executable="Other"), package_dump(), id="executable"),
        pytest.param(
            {**plist(), "CFBundleIconFile": "OtherIcon"},
            package_dump(),
            id="icon-file",
        ),
        pytest.param(
            plist(),
            {
                **package_dump(),
                "platforms": [{"platformName": "macos", "version": "14.0"}],
            },
            id="minimum-version",
        ),
    ],
)
def test_rejects_cross_source_mismatches(
    tmp_path: Path,
    plist_value: dict[str, object],
    dump_value: dict[str, object],
) -> None:
    with pytest.raises(ScriptError):
        load_configuration(tmp_path, plist_value, dump_value)


unsafe_target_dump = package_dump()
unsafe_target = {**unsafe_target_dump["targets"][0], "path": "../Client"}


@pytest.mark.parametrize(
    ("plist_value", "dump_value"),
    [
        pytest.param(
            {**plist(), "LSArchitecturePriority": ["arm64", "arm64"]},
            package_dump(),
            id="duplicate-architectures",
        ),
        pytest.param(
            plist(),
            {**unsafe_target_dump, "targets": [unsafe_target]},
            id="unsafe-target-path",
        ),
    ],
)
def test_rejects_duplicate_architectures_and_unsafe_paths(
    tmp_path: Path,
    plist_value: dict[str, object],
    dump_value: dict[str, object],
) -> None:
    with pytest.raises(ScriptError):
        load_configuration(tmp_path, plist_value, dump_value)


def test_rejects_unsafe_architecture_arguments(tmp_path: Path) -> None:
    with pytest.raises(ScriptError, match="Swift architecture names"):
        load_configuration(
            tmp_path,
            {**plist(), "LSArchitecturePriority": ["arm64 --verbose"]},
            package_dump(),
        )


def target(
    name: str, kind: str, resources: list[dict[str, object]]
) -> dict[str, object]:
    return {
        "name": name,
        "type": kind,
        "path": f"Sources/{name}",
        "resources": resources,
    }


COPY_ICON = [{"path": "Resources/Icon.png", "rule": {"copy": {}}}]


def test_reports_executable_as_resource_target(tmp_path: Path) -> None:
    configuration = load_configuration(tmp_path, plist(), package_dump())

    assert configuration.package.resource_target_path == Path("Sources/Client")


def test_library_may_hold_resources_while_executable_has_none(tmp_path: Path) -> None:
    dump = {
        **package_dump(),
        "targets": [
            target("Client", "executable", []),
            target("Core", "regular", COPY_ICON),
            target("CoreTests", "test", COPY_ICON),
        ],
    }

    configuration = load_configuration(tmp_path, plist(), dump)

    assert configuration.package.resource_target_path == Path("Sources/Core")
    assert configuration.copied_resource_source_paths == (
        tmp_path.resolve() / "Sources/Core/Resources/Icon.png",
    )


@pytest.mark.parametrize(
    "targets",
    [
        pytest.param(
            [
                target("Client", "executable", COPY_ICON),
                target("Core", "regular", COPY_ICON),
            ],
            id="two-resource-targets",
        ),
        pytest.param(
            [target("Client", "executable", []), target("Core", "regular", [])],
            id="no-resource-target",
        ),
    ],
)
def test_rejects_other_than_one_resource_target(
    tmp_path: Path, targets: list[dict[str, object]]
) -> None:
    with pytest.raises(ScriptError, match="exactly one non-test target"):
        load_configuration(tmp_path, plist(), {**package_dump(), "targets": targets})

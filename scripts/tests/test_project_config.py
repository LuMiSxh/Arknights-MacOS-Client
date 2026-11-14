# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
from pathlib import Path

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


def target(
    name: str, kind: str, resources: list[dict[str, object]]
) -> dict[str, object]:
    return {
        "name": name,
        "type": kind,
        "path": f"Sources/{name}",
        "resources": resources,
    }

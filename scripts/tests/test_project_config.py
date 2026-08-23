# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
from pathlib import Path

import pytest
from lib.common import ScriptError
from lib.project_config import ProjectConfiguration, load_project_configuration


def plist(
    *, languages: list[str] | None = None, executable: str = "Client"
) -> dict[str, object]:
    return {
        "CFBundleDisplayName": "Example Client",
        "CFBundleName": "Example Client",
        "CFBundleExecutable": executable,
        "CFBundleIdentifier": "example.client",
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleIconName": "AppIcon",
        "CFBundleIconFile": "AppIcon",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": languages or ["en", "de"],
        "LSMinimumSystemVersion": "15.0",
        "LSArchitecturePriority": ["arm64"],
    }


def package_dump(
    *,
    languages: list[str] | None = None,
    name: str = "Client",
    resources: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    languages = languages or ["en", "de"]
    return {
        "name": name,
        "defaultLocalization": "en",
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
                    *(
                        {
                            "path": f"Resources/{language}.lproj",
                            "rule": {"process": {}},
                        }
                        for language in languages
                    ),
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
    assert configuration.dmg_name == "Example Client.dmg"
    assert configuration.target_directory == configuration.project_directory / (
        "Sources/Client"
    )
    assert configuration.resource_directory == configuration.target_directory / (
        "Resources"
    )
    assert configuration.swift_resource_bundle_name == "Client_Client.bundle"
    assert configuration.copied_resource_source_paths == (
        configuration.target_directory / "Resources/Icon.png",
    )


def test_renames_languages_and_resources_are_derived_automatically(
    tmp_path: Path,
) -> None:
    languages = ["en", "de", "ja"]
    resources = [
        {"path": "Assets/Brand.png", "rule": {"copy": {}}},
        *(
            {"path": f"Assets/{language}.lproj", "rule": {"process": {}}}
            for language in languages
        ),
    ]
    configuration = load_configuration(
        tmp_path,
        plist(languages=languages, executable="Renamed"),
        package_dump(languages=languages, name="Renamed", resources=resources),
    )

    assert configuration.swift_resource_bundle_name == "Renamed_Renamed.bundle"
    assert configuration.package.processed_resource_paths == tuple(
        Path(f"Assets/{language}.lproj") for language in languages
    )
    assert configuration.copied_resource_source_paths == (
        configuration.target_directory / "Assets/Brand.png",
    )


@pytest.mark.parametrize(
    ("plist_value", "dump_value"),
    [
        pytest.param(plist(executable="Other"), package_dump(), id="executable"),
        pytest.param(plist(languages=["en", "fr"]), package_dump(), id="localizations"),
        pytest.param(
            {**plist(), "CFBundleIconFile": "OtherIcon"},
            package_dump(),
            id="icon-file",
        ),
        pytest.param(
            plist(),
            {**package_dump(), "defaultLocalization": "de"},
            id="default-localization",
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
            plist(languages=["en", "en"]), package_dump(), id="duplicate-languages"
        ),
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
def test_rejects_duplicate_languages_architectures_and_unsafe_paths(
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

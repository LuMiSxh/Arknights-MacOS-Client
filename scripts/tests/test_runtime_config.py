# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import pytest
import runtime_config


def interface(architecture: str, dxmt_libraries: list[str]) -> dict[str, object]:
    return {
        "archive": {"wineDirectory": "Wine", "dxmtDirectory": "DXMT"},
        "executables": ["bin/wine64", "bin/wineserver"],
        "features": {
            "hardwareCursor": True,
            "metalFXSpatialUpscaling": True,
            "nativeFullscreenSpace": True,
        },
        "requiredFiles": [
            f"lib/wine/{architecture}-unix/winecoreaudio.so",
            f"lib/wine/{architecture}-windows/winemetal.dll",
        ],
        "macDriver": f"lib/wine/{architecture}-unix/winemac.so",
        "launcher": {"path": "bin/Arknights", "target": "wine64"},
        "dxmt": {
            "payloadDirectory": "DXMT",
            "destinations": {"x64": "system32"},
            "libraries": dxmt_libraries,
        },
    }


def provenance(components: tuple[str, ...]) -> dict[str, str]:
    value = {
        "buildRepository": "https://github.com/LuMiSxh/Arknights-MacOS-Runtime",
        "buildCommit": "1" * 40,
    }
    for index, name in enumerate(components, start=2):
        value[f"{name}Repository"] = f"https://github.com/example/{name}"
        value[f"{name}Commit"] = str(index) * 40
    return value


def lane(
    architecture: str,
    macos: str,
    revision: int,
    version: str,
    dxmt_libraries: list[str],
    components: dict[str, str],
) -> dict[str, object]:
    return {
        "minimumMacOS": macos,
        "prefixRevision": revision,
        "runtime": {
            "name": f"Arknights macOS Runtime {version}",
            "version": version,
            "url": (
                "https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/"
                f"v{version}/Arknights-MacOS-Runtime-v{version}.tar.gz"
            ),
            "sha256": "a" * 64,
            "sizeBytes": 400_000_000,
        },
        "interface": interface(architecture, dxmt_libraries),
        "components": components,
        "provenance": provenance(tuple(components)),
    }


def valid_config() -> dict[str, object]:
    return {
        "schemaVersion": 3,
        "architecture": "x86",
        "prefixRevision": 2,
        "lanes": {
            "x86": lane(
                "x86_64",
                "15.0",
                2,
                "0.8.0",
                ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll"],
                {"wine": "11.17", "dxmt": "0.80", "moltenvk": "1.4.2"},
            ),
            "arm": lane(
                "aarch64",
                "26.0",
                1,
                "0.8.0+arm",
                ["d3d10core.dll", "d3d11.dll", "dxgi.dll"],
                {"wine": "11.18", "fex": "2610", "mesa": "25.0", "dxmt": "0.80"},
            ),
        },
    }


def write_config(path: Path, value: dict[str, object]) -> None:
    path.write_text(json.dumps(value), encoding="utf-8")


def test_validates_complete_configuration(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, valid_config())

    loaded = runtime_config.load_runtime_config(config)

    assert loaded.architecture == "x86"
    assert loaded.prefix_revision == 2
    assert set(loaded.lanes) == {"x86", "arm"}
    assert loaded.selected.name == "x86"
    assert loaded.selected.runtime.version == "0.8.0"
    assert loaded.selected.runtime.size_bytes == 400_000_000
    assert loaded.selected.minimum_macos == "15.0"
    assert loaded.selected_layout == loaded.for_architecture("x86")
    assert loaded.lane("arm").prefix_revision == 1
    assert loaded.lane("arm").minimum_macos == "26.0"


def test_selects_each_lane_explicitly(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, valid_config())
    loaded = runtime_config.load_runtime_config(config)

    x86 = loaded.for_architecture("x86")
    arm = loaded.for_architecture("arm")

    assert all("x86_64" not in str(path) for path in arm.required_files)
    assert "aarch64-unix" in str(arm.mac_driver)
    assert any("aarch64-windows" in str(path) for path in arm.required_files)
    assert "winemetal.dll" not in arm.dxmt.libraries
    assert arm.executables == x86.executables


def test_top_level_architecture_selects_the_bridge_fallback(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["architecture"] = "arm"
    write_config(config, value)

    loaded = runtime_config.load_runtime_config(config)

    assert loaded.architecture == "arm"
    assert loaded.selected_layout == loaded.for_architecture("arm")
    assert "aarch64-unix" in str(loaded.selected_layout.mac_driver)


def test_reads_runtime_features(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, valid_config())

    loaded = runtime_config.load_runtime_config(config)

    features = loaded.selected_layout.features
    assert features.hardware_cursor is True
    assert features.metal_fx_spatial_upscaling is True
    assert features.native_fullscreen_space is True


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda value: value.update(schemaVersion=2), "schemaVersion must be 3"),
        (
            lambda value: value["lanes"]["x86"]["runtime"].update(sha256="latest"),
            "lowercase SHA-256",
        ),
        (
            lambda value: value["lanes"]["x86"]["runtime"].update(sizeBytes=0),
            "pin must be complete or empty",
        ),
        (
            lambda value: value["lanes"]["x86"]["runtime"].update(
                url="http://example.com/runtime.tar.gz"
            ),
            "must use HTTPS",
        ),
        (
            lambda value: value["lanes"]["x86"].update(minimumMacOS="macOS 15"),
            "minimumMacOS must be a version",
        ),
        (
            lambda value: value["lanes"]["x86"].update(prefixRevision=0),
            "positive integer",
        ),
    ],
)
def test_rejects_invalid_lane_values(
    tmp_path: Path, mutate: object, message: str
) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    mutate(value)  # type: ignore[operator]
    write_config(config, value)

    with pytest.raises(RuntimeError, match=message):
        runtime_config.load_runtime_config(config)


@pytest.mark.parametrize("key", ["runtime", "interface", "buildRecipe", "armInterface"])
def test_rejects_the_obsolete_top_level_contract(tmp_path: Path, key: str) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value[key] = {}
    write_config(config, value)

    with pytest.raises(RuntimeError, match="keep the runtime contract in lanes"):
        runtime_config.load_runtime_config(config)


def test_accepts_an_unpublished_lane(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["lanes"]["arm"]["runtime"] = {
        "name": "Arknights macOS Runtime 0.9.0+arm",
        "version": "0.9.0+arm",
        "url": "",
        "sha256": "",
        "sizeBytes": 0,
    }
    value["lanes"]["arm"]["components"] = {}
    value["lanes"]["arm"]["provenance"] = {}
    write_config(config, value)

    loaded = runtime_config.load_runtime_config(config)

    assert not loaded.lane("arm").runtime.is_available
    assert loaded.lane("arm").layout.mac_driver.parts[-1] == "winemac.so"


def test_rejects_a_partial_unpublished_pin(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["lanes"]["arm"]["runtime"]["sizeBytes"] = 0
    write_config(config, value)

    with pytest.raises(RuntimeError, match="pin must be complete or empty"):
        runtime_config.load_runtime_config(config)


def test_allows_a_missing_lane_but_fails_when_it_is_selected(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    del value["lanes"]["arm"]
    write_config(config, value)

    loaded = runtime_config.load_runtime_config(config)

    with pytest.raises(RuntimeError, match="no arm lane"):
        loaded.lane("arm")


def test_rejects_an_unknown_lane(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["lanes"]["arm64"] = value["lanes"]["arm"]
    write_config(config, value)

    with pytest.raises(RuntimeError, match="unknown lanes: arm64"):
        runtime_config.load_runtime_config(config)


def test_new_component_requires_matching_provenance(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["lanes"]["x86"]["components"]["newMedia"] = "2"
    write_config(config, value)

    with pytest.raises(RuntimeError, match="missing component sources"):
        runtime_config.load_runtime_config(config)

    value["lanes"]["x86"]["provenance"]["newMediaRepository"] = (
        "https://example.com/media"
    )
    value["lanes"]["x86"]["provenance"]["newMediaCommit"] = "1" * 40
    write_config(config, value)
    runtime_config.load_runtime_config(config)


@pytest.mark.parametrize("state", ["missing", "stale", "current"])
def test_prepared_runtime_is_used_only_when_it_matches_the_lane_pin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, state: str
) -> None:
    write_config(tmp_path / "runtime.json", valid_config())
    config = runtime_config.load_runtime_config(tmp_path / "runtime.json")
    lane = config.lane("arm")
    directory = tmp_path / ".build" / "runtime-arm"
    monkeypatch.setattr(runtime_config, "runtime_is_valid", lambda *_: True)
    if state != "missing":
        directory.mkdir(parents=True)
        revision = "0" * 64 if state == "stale" else lane.runtime.sha256
        (directory / runtime_config.PREPARED_REVISION_FILE).write_text(
            revision, encoding="utf-8"
        )

    expected = directory if state == "current" else None
    assert runtime_config.prepared_runtime(tmp_path, "arm") == expected
    assert runtime_config.prepared_runtime(tmp_path, "x86") is None

# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import pytest
import runtime_config


def valid_config() -> dict[str, object]:
    return {
        "schemaVersion": 2,
        "prefixRevision": 1,
        "runtime": {
            "name": "Test runtime",
            "url": "https://example.com/runtime.tar.gz",
            "sha256": "a" * 64,
        },
        "buildRecipe": {
            "url": "https://example.com/source.tar.gz",
            "sha256": "b" * 64,
        },
        "interface": {
            "archive": {"wineDirectory": "Wine", "dxmtDirectory": "DXMT"},
            "executables": ["bin/wine64", "bin/wineserver"],
            "requiredFiles": ["lib/wine/x86_64-windows/winemetal.dll"],
            "macDriver": "lib/wine/x86_64-unix/winemac.so",
            "launcher": {"path": "bin/Arknights", "target": "wine64"},
            "dxmt": {
                "payloadDirectory": "DXMT",
                "destinations": {"x64": "system32", "x32": "syswow64"},
                "libraries": [
                    "d3d10core.dll",
                    "d3d11.dll",
                    "dxgi.dll",
                    "winemetal.dll",
                ],
            },
        },
        "components": {
            "wine": "1",
            "dxmt": "1",
            "gstreamer": "1",
            "ffmpeg": "1",
            "moltenvk": "1",
            "wineGecko": "1",
        },
        "provenance": {
            "buildRepository": "https://example.com/build",
            "buildCommit": "c" * 40,
            "wineRepository": "https://example.com/wine",
            "wineCommit": "d" * 40,
            "dxmtRepository": "https://example.com/dxmt",
            "dxmtCommit": "e" * 40,
            "moltenvkRepository": "https://example.com/moltenvk",
            "moltenvkCommit": "f" * 40,
            "gstreamerRepository": "https://example.com/gstreamer",
            "gstreamerCommit": "a" * 40,
            "ffmpegRepository": "https://example.com/ffmpeg",
            "ffmpegCommit": "b" * 40,
            "wineGeckoRepository": "https://example.com/gecko",
            "wineGeckoCommit": "c" * 40,
            "nixpkgsRepository": "https://example.com/nixpkgs",
            "nixpkgsCommit": "e" * 40,
        },
    }


def write_config(path: Path, value: dict[str, object]) -> None:
    path.write_text(json.dumps(value), encoding="utf-8")


def test_reads_nested_scalar(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, {"runtime": {"url": "https://example.com/runtime.tar.gz"}})

    assert (
        runtime_config.read_value(config, "runtime.url")
        == "https://example.com/runtime.tar.gz"
    )


def test_rejects_missing_value(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, {})

    with pytest.raises(RuntimeError):
        runtime_config.read_value(config, "runtime.url")


def test_validates_complete_configuration(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, valid_config())

    loaded = runtime_config.load_runtime_config(config)

    assert loaded.runtime_url == "https://example.com/runtime.tar.gz"
    assert tuple(loaded.layout.dxmt.destinations) == (
        ("x64", "system32"),
        ("x32", "syswow64"),
    )


def test_rejects_invalid_checksum(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    assert isinstance(value["runtime"], dict)
    value["runtime"]["sha256"] = "latest"
    write_config(config, value)

    with pytest.raises(RuntimeError):
        runtime_config.validate_config(config)


def test_rejects_previous_schema(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["schemaVersion"] = 1
    write_config(config, value)

    with pytest.raises(RuntimeError, match="schemaVersion must be 2"):
        runtime_config.validate_config(config)


def test_new_component_requires_and_accepts_matching_provenance(
    tmp_path: Path,
) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    assert isinstance(value["components"], dict)
    assert isinstance(value["provenance"], dict)
    value["components"]["newMedia"] = "2"
    write_config(config, value)

    with pytest.raises(RuntimeError, match="missing component sources"):
        runtime_config.validate_config(config)

    value["provenance"]["newMediaRepository"] = "https://example.com/media"
    value["provenance"]["newMediaCommit"] = "1" * 40
    write_config(config, value)
    runtime_config.validate_config(config)

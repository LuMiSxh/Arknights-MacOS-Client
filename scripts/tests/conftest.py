# SPDX-License-Identifier: MPL-2.0

"""Shared schema-3 runtime fixtures for the script tests."""

from __future__ import annotations

from typing import Any


def interface(architecture: str, dxmt_libraries: list[str]) -> dict[str, Any]:
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


def runtime_manifest() -> dict[str, Any]:
    return {
        "schemaVersion": 3,
        "architecture": "x86",
        "prefixRevision": 2,
        "lanes": {
            "x86": {
                "minimumMacOS": "15.0",
                "prefixRevision": 2,
                "runtime": {
                    "name": "Arknights macOS Runtime 0.8.0",
                    "version": "0.8.0",
                    "url": (
                        "https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/"
                        "download/v0.8.0/Arknights-MacOS-Runtime-v0.8.0.tar.gz"
                    ),
                    "sha256": "a" * 64,
                    "sizeBytes": 400_000_000,
                },
                "interface": interface(
                    "x86_64",
                    ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll"],
                ),
                "components": {
                    "wine": "11.17",
                    "dxmt": "0.80-361-g9839e55",
                    "moltenvk": "1.4.2",
                },
                "provenance": {
                    "buildRepository": (
                        "https://github.com/LuMiSxh/Arknights-MacOS-Runtime"
                    ),
                    "buildCommit": "1" * 40,
                    "wineRepository": "https://github.com/dappermint/winecx",
                    "wineCommit": "2" * 40,
                    "dxmtRepository": "https://github.com/3Shain/dxmt",
                    "dxmtCommit": "3" * 40,
                    "moltenvkRepository": "https://github.com/KhronosGroup/MoltenVK",
                    "moltenvkCommit": "4" * 40,
                },
            },
            "arm": {
                "minimumMacOS": "26.0",
                "prefixRevision": 1,
                "runtime": {
                    "name": "Arknights macOS Runtime 0.8.0+arm",
                    "version": "0.8.0+arm",
                    "url": (
                        "https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/"
                        "download/v0.8.0+arm/Arknights-MacOS-Runtime-v0.8.0+arm.tar.gz"
                    ),
                    "sha256": "b" * 64,
                    "sizeBytes": 380_000_000,
                },
                "interface": interface(
                    "aarch64", ["d3d10core.dll", "d3d11.dll", "dxgi.dll"]
                ),
                "components": {
                    "wine": "11.18",
                    "fex": "2610",
                    "mesa": "25.0",
                    "dxmt": "0.80",
                },
                "provenance": {
                    "buildRepository": (
                        "https://github.com/LuMiSxh/Arknights-MacOS-Runtime"
                    ),
                    "buildCommit": "5" * 40,
                    "wineRepository": "https://gitlab.winehq.org/wine/wine",
                    "wineCommit": "6" * 40,
                    "fexRepository": "https://github.com/FEX-Emu/FEX",
                    "fexCommit": "7" * 40,
                    "mesaRepository": "https://gitlab.freedesktop.org/mesa/mesa",
                    "mesaCommit": "8" * 40,
                    "dxmtRepository": "https://github.com/3Shain/dxmt",
                    "dxmtCommit": "9" * 40,
                },
            },
        },
    }

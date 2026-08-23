#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Regenerate the layered app icon, README preview, and fallback assets."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    remove_path,
    require_command,
    require_directory,
    require_file,
    run,
    run_main,
    success,
    warning,
)
from lib.console import spinner
from lib.project_config import ProjectConfiguration, load_project_configuration

DEFAULT_ICON_COMPOSER = Path(
    "/Applications/Icon Composer.app/Contents/Executables/ictool"
)


def icon_composer() -> Path:
    discovered = shutil.which("ictool")
    if discovered:
        return Path(discovered)
    if DEFAULT_ICON_COMPOSER.is_file():
        return DEFAULT_ICON_COMPOSER
    fail("Icon Composer command not found; install Icon Composer or add ictool to PATH")


def compile_arguments(
    source: Path,
    destination: Path,
    configuration: ProjectConfiguration,
) -> list[str | Path]:
    return [
        "actool",
        source,
        "--compile",
        destination,
        "--output-partial-info-plist",
        destination / "Info.plist",
        "--app-icon",
        configuration.product.icon_name,
        "--enable-on-demand-resources",
        "NO",
        "--development-region",
        configuration.product.development_region,
        "--target-device",
        "mac",
        "--minimum-deployment-target",
        configuration.package.macos_version,
        "--platform",
        "macosx",
        "--notices",
        "--warnings",
        "--errors",
        "--output-format",
        "human-readable-text",
    ]


def generate(configuration: ProjectConfiguration | None = None) -> None:
    configuration = configuration or load_project_configuration()
    project = configuration.project_directory
    icon_name = configuration.product.icon_name
    icon_file = configuration.product.icon_file
    icon_filename = icon_file if Path(icon_file).suffix else f"{icon_file}.icns"
    require_command("actool")
    require_command("sips")
    composer = icon_composer()
    source = require_directory(project / f"Resources/{icon_name}.icon")

    build_directory = project / BUILD_DIR.relative_to(PROJECT_DIR)
    rendered = build_directory / f"{icon_name}.png"
    preview = project / f"Resources/{icon_name}.png"
    catalog = build_directory / f"{icon_name}.xcassets"
    iconset = catalog / f"{icon_name}.appiconset"
    compiled = build_directory / f"{icon_name}.compiled"
    dynamic = build_directory / f"{icon_name}.dynamic"
    output_icns = project / "Resources" / icon_filename
    output_assets = project / "Resources/Assets.car"
    for path in (catalog, compiled, dynamic):
        remove_path(path)
    for path in (iconset, compiled, dynamic):
        path.mkdir(parents=True)

    with spinner("Rendering the Icon Composer source"):
        run(
            [
                composer,
                source,
                "--export-image",
                "--output-file",
                rendered,
                "--platform",
                "macOS",
                "--rendition",
                "Default",
                "--width",
                "1024",
                "--height",
                "1024",
                "--scale",
                "1",
            ]
        )
        run(
            ["sips", "--resampleHeightWidth", "512", "512", rendered, "--out", preview],
            capture=True,
        )

    with spinner("Compiling the native layered icon"):
        result = subprocess.run(
            [str(value) for value in compile_arguments(source, dynamic, configuration)],
            text=True,
            capture_output=True,
            check=False,
        )
    (dynamic / "actool.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if (
        result.returncode == 0
        and (dynamic / icon_filename).is_file()
        and (dynamic / "Assets.car").is_file()
    ):
        shutil.copyfile(dynamic / icon_filename, output_icns)
        shutil.copyfile(dynamic / "Assets.car", output_assets)
        success("Built the native layered app icon")
        return

    warning("Native .icon compilation is unavailable; using the asset-catalog fallback")
    require_command("magick")
    contents = require_file(project / f"Resources/{icon_name}AssetContents.json")
    shutil.copyfile(contents, iconset / "Contents.json")
    for size in (16, 32, 128, 256, 512):
        for scale, pixels in ((1, size), (2, size * 2)):
            suffix = "" if scale == 1 else "@2x"
            output = iconset / f"icon_{size}x{size}{suffix}.png"
            run(["magick", rendered, "-resize", f"{pixels}x{pixels}", output])
    run(compile_arguments(catalog, compiled, configuration))
    shutil.copyfile(require_file(compiled / icon_filename), output_icns)
    shutil.copyfile(require_file(compiled / "Assets.car"), output_assets)
    success("Built the asset-catalog app icon fallback")


def main() -> None:
    generate()


if __name__ == "__main__":
    run_main(main)

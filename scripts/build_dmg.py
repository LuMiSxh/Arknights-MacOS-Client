#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["dmgbuild==1.6.7"]
# ///
# SPDX-License-Identifier: MPL-2.0

"""Build and verify the distributable application disk image."""

from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from build_app import build
from lib.common import info, remove_path, run, run_main, success
from lib.project_config import ProjectConfiguration, load_project_configuration


def dmgbuild_arguments(
    app: Path,
    destination: Path,
    configuration: ProjectConfiguration,
) -> list[str | Path]:
    project = configuration.project_directory
    return [
        sys.executable,
        "-m",
        "dmgbuild",
        "--settings",
        project / "scripts/lib/dmg_settings.py",
        "-D",
        f"app_bundle={app}",
        "-D",
        f"app_name={configuration.app_bundle_name}",
        configuration.product.display_name,
        destination,
    ]


def build_dmg(
    runtime: Path,
    configuration: ProjectConfiguration | None = None,
) -> Path:
    configuration = configuration or load_project_configuration()
    project = configuration.project_directory
    app = build(runtime, project_configuration=configuration)
    dist = project / "dist"
    destination = dist / configuration.dmg_name
    with tempfile.TemporaryDirectory(prefix=".dmg-build.", dir=dist) as name:
        staged = Path(name) / destination.name
        info("Creating the compressed disk image")
        run(dmgbuild_arguments(app, staged, configuration), cwd=project)
        info("Verifying the disk image")
        run(["hdiutil", "verify", staged])
        remove_path(destination)
        staged.replace(destination)
    success(f"Built {destination.relative_to(project)}")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True, type=Path)
    arguments = parser.parse_args()
    build_dmg(arguments.runtime.resolve())


if __name__ == "__main__":
    run_main(main)

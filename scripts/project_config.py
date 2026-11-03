#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Print project metadata derived from Info.plist and Package.swift.

With github-env, print the release-job names as NAME=value lines for GITHUB_ENV.
"""

from __future__ import annotations

import argparse
from collections.abc import Callable

from lib.common import run_main
from lib.project_config import (
    SPARKLE_DELTA_SOURCE_COUNT,
    ProjectConfiguration,
    load_project_configuration,
)

FIELDS: dict[str, Callable[[ProjectConfiguration], str]] = {
    "app-bundle-name": lambda configuration: configuration.app_bundle_name,
    "display-name": lambda configuration: configuration.product.display_name,
    "dmg-name": lambda configuration: configuration.dmg_name,
    "executable-name": lambda configuration: configuration.product.executable_name,
    "release-asset-stem": lambda configuration: configuration.release_asset_stem,
    "sparkle-update-name": lambda configuration: configuration.sparkle_update_name,
    "sparkle-delta-sources": lambda configuration: str(SPARKLE_DELTA_SOURCE_COUNT),
    "marketing-version": lambda configuration: configuration.product.marketing_version,
    "test-targets": lambda configuration: "\n".join(
        configuration.package.test_target_names
    ),
    "swift-architecture-arguments": lambda configuration: " ".join(
        f"--arch {architecture}"
        for architecture in configuration.product.architecture_priority
    ),
}


# One run exports these names, so the release job parses Package.swift once.
GITHUB_ENV_COMMAND = "github-env"
GITHUB_ENVIRONMENT: dict[str, str] = {
    "APP_NAME": "app-bundle-name",
    "DISPLAY_NAME": "display-name",
    "DMG_NAME": "dmg-name",
    "UPDATE_NAME": "sparkle-update-name",
    "DELTA_SOURCES": "sparkle-delta-sources",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("field", choices=(*FIELDS, GITHUB_ENV_COMMAND))
    arguments = parser.parse_args()
    configuration = load_project_configuration()
    if arguments.field == GITHUB_ENV_COMMAND:
        for name, field in GITHUB_ENVIRONMENT.items():
            print(f"{name}={FIELDS[field](configuration)}")
        return
    print(FIELDS[arguments.field](configuration))


if __name__ == "__main__":
    run_main(main)

#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Print project metadata derived from Info.plist and Package.swift."""

from __future__ import annotations

import argparse
from collections.abc import Callable

from lib.common import run_main
from lib.project_config import ProjectConfiguration, load_project_configuration

FIELDS: dict[str, Callable[[ProjectConfiguration], str]] = {
    "app-bundle-name": lambda configuration: configuration.app_bundle_name,
    "display-name": lambda configuration: configuration.product.display_name,
    "dmg-name": lambda configuration: configuration.dmg_name,
    "executable-name": lambda configuration: configuration.product.executable_name,
    "marketing-version": lambda configuration: configuration.product.marketing_version,
    "swift-architecture-arguments": lambda configuration: " ".join(
        f"--arch {architecture}"
        for architecture in configuration.product.architecture_priority
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("field", choices=tuple(FIELDS))
    arguments = parser.parse_args()
    print(FIELDS[arguments.field](load_project_configuration()))


if __name__ == "__main__":
    run_main(main)

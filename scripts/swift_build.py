#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Build the SwiftPM product with the active macOS SDK metadata."""

from __future__ import annotations

import argparse

from lib.common import run_main
from lib.project_config import load_project_configuration
from lib.swift_build import run_swift_build


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--configuration", choices=("debug", "release"), default="debug"
    )
    parser.add_argument("--sdk", dest="sdk_name", default="macosx")
    parser.add_argument("--show-bin-path", action="store_true")
    arguments = parser.parse_args()
    result = run_swift_build(
        load_project_configuration(),
        arguments.configuration,
        sdk_name=arguments.sdk_name,
        show_bin_path=arguments.show_bin_path,
        capture=arguments.show_bin_path,
    )
    if arguments.show_bin_path:
        print(result.stdout.strip())


if __name__ == "__main__":
    run_main(main)

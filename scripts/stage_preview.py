#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Stage the app resources next to the debug executable for `just preview`.

A bare SwiftPM executable has no app bundle, so the launcher reads its resources
from the executable's own directory.
"""

import argparse
from pathlib import Path

from lib.bundled_resources import stage_app_resources
from lib.common import run_main
from lib.console import warning
from lib.licenses import stage_bundle
from lib.project_config import load_project_configuration


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary_dir", type=Path)
    arguments = parser.parse_args()
    configuration = load_project_configuration()
    stage_app_resources(configuration, arguments.binary_dir)
    for message in stage_bundle(
        configuration.project_directory, arguments.binary_dir, strict=False
    ):
        warning(message)


if __name__ == "__main__":
    run_main(main)

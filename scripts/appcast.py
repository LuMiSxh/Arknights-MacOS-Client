#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Edit and re-sign the canonical Sparkle appcast outside a release build.

`merge` appends the generated item of a new build to the canonical feed; the
release workflow then signs the result. `check-preserved` fails when a canonical
item is missing or changed. `promote` moves a canary release to the stable channel.
`legacy` writes the stable-only feed that launchers 1.0.2 and older read from the
latest GitHub release. Both sign the result with the K0 seed from the environment
and verify it.
"""

import argparse
import os
from pathlib import Path

from lib import sparkle_appcast
from lib.common import fail, run_main
from lib.console import success
from lib.project_config import MINIMUM_MIGRATABLE_BUILD


def edit_and_sign(arguments: argparse.Namespace) -> None:
    private_key = os.environ.get("SPARKLE_ED25519_PRIVATE_KEY", "")
    if not private_key:
        fail("SPARKLE_ED25519_PRIVATE_KEY is required to sign the appcast")
    root = sparkle_appcast.parse(arguments.appcast.read_bytes(), "canonical")
    if arguments.command == "promote":
        build = sparkle_appcast.promote_to_stable(root, arguments.tag)
        sparkle_appcast.validate_update_gate(root, build, MINIMUM_MIGRATABLE_BUILD)
    else:
        sparkle_appcast.keep_stable_items(root)
    arguments.output.write_bytes(sparkle_appcast.serialize(root))
    sparkle_appcast.sign_appcast(arguments.sign_update, private_key, arguments.output)
    sparkle_appcast.verify(arguments.sign_update, private_key, arguments.output)
    success(f"Wrote and verified {arguments.output.name}")


def merge(arguments: argparse.Namespace) -> None:
    generated = sparkle_appcast.parse(arguments.generated.read_bytes(), "generated")
    canonical = (
        sparkle_appcast.parse(arguments.canonical.read_bytes(), "canonical")
        if arguments.canonical
        else None
    )
    merged = sparkle_appcast.merge_new_item(canonical, generated, arguments.build)
    arguments.output.write_bytes(sparkle_appcast.serialize(merged))
    success(f"Merged build {arguments.build} into {arguments.output.name}")


def check_preserved(arguments: argparse.Namespace) -> None:
    sparkle_appcast.check_items_preserved(
        sparkle_appcast.parse(arguments.canonical.read_bytes(), "canonical"),
        sparkle_appcast.parse(arguments.appcast.read_bytes(), "new"),
    )
    success("Every canonical appcast item is unchanged")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    merge_parser = commands.add_parser("merge", help="append the new build's item")
    merge_parser.add_argument("--generated", type=Path, required=True)
    merge_parser.add_argument("--canonical", type=Path)
    merge_parser.add_argument("--output", type=Path, required=True)
    merge_parser.add_argument("--build", type=int, required=True)
    merge_parser.set_defaults(handler=merge)
    preserved_parser = commands.add_parser(
        "check-preserved", help="fail when a canonical item changed"
    )
    preserved_parser.add_argument("--canonical", type=Path, required=True)
    preserved_parser.add_argument("--appcast", type=Path, required=True)
    preserved_parser.set_defaults(handler=check_preserved)
    for name, help_text in (
        ("promote", "make a canary release's item stable"),
        ("legacy", "write the stable-only feed"),
    ):
        command = commands.add_parser(name, help=help_text)
        command.add_argument("--appcast", type=Path, required=True)
        command.add_argument("--output", type=Path, required=True)
        command.add_argument("--sign-update", type=Path, required=True)
        if name == "promote":
            command.add_argument("--tag", required=True)
        command.set_defaults(handler=edit_and_sign)
    arguments = parser.parse_args()
    arguments.handler(arguments)


if __name__ == "__main__":
    run_main(main)

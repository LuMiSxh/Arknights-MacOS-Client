#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Safely extract a verified Wine runtime archive for release packaging."""

from __future__ import annotations

import argparse
import tarfile
from pathlib import Path, PurePosixPath

from lib.common import fail, run_main


def stays_within_root(path: PurePosixPath) -> bool:
    depth = 0
    for part in path.parts:
        if part in ("", "."):
            continue
        if part == "..":
            depth -= 1
            if depth < 0:
                return False
        else:
            depth += 1
    return True


def validate_member(member: tarfile.TarInfo) -> PurePosixPath:
    path = PurePosixPath(member.name)
    if path.is_absolute() or ".." in path.parts:
        fail(f"unsafe archive path: {member.name}")
    if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
        fail(f"unsupported archive entry: {member.name}")

    if member.issym():
        target = PurePosixPath(member.linkname)
        if target.is_absolute() or not stays_within_root(path.parent / target):
            fail(f"unsafe symbolic link: {member.name} -> {member.linkname}")
    elif member.islnk():
        target = PurePosixPath(member.linkname)
        if target.is_absolute() or not stays_within_root(target):
            fail(f"unsafe hard link: {member.name} -> {member.linkname}")
    return path


def is_platform_metadata(path: PurePosixPath) -> bool:
    return path.parts[:1] == ("__MACOSX",) or any(
        part.startswith("._") for part in path.parts
    )


def extract(archive: Path, destination: Path) -> Path:
    if destination.exists():
        fail(f"destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)

    with tarfile.open(archive, mode="r:gz") as contents:
        validated = [
            (member, validate_member(member)) for member in contents.getmembers()
        ]
        members = [
            member for member, path in validated if not is_platform_metadata(path)
        ]
        paths = [path for _, path in validated if not is_platform_metadata(path)]
        top_levels = {
            path.parts[0] for path in paths if path.parts and path.parts[0] != "."
        }
        if len(top_levels) != 1:
            fail("runtime archive must contain exactly one top-level directory")

        destination.mkdir()
        contents.extractall(destination, members=members, filter="data")

    runtime_root = destination / next(iter(top_levels))
    if not runtime_root.is_dir():
        fail("runtime archive top-level entry is not a directory")
    return runtime_root


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    if not arguments.archive.is_file():
        fail(f"archive not found: {arguments.archive}")
    print(extract(arguments.archive.resolve(), arguments.destination.resolve()))


if __name__ == "__main__":
    run_main(main)

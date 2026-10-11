#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Safely extract a verified Wine runtime archive for release packaging."""

from __future__ import annotations

import argparse
import posixpath
import tarfile
from pathlib import Path, PurePosixPath

from lib.common import fail, remove_path, run_main

# Runtime 0.7.0 ships its license texts beside the runtime directory.
RUNTIME_COMPANIONS = frozenset({"Licenses", "NOTICE.md"})


def validate_member(member: tarfile.TarInfo) -> PurePosixPath:
    """Reject absolute paths, `..` components and links that leave the archive."""
    path = PurePosixPath(member.name)
    if path.is_absolute() or ".." in path.parts:
        fail(f"unsafe archive path: {member.name}")
    if member.issym() or member.islnk():
        target = PurePosixPath(member.linkname)
        # Symbolic links resolve against their own directory; hard links against the root.
        base = path.parent if member.issym() else PurePosixPath()
        resolved = posixpath.normpath(base / target)
        if target.is_absolute() or resolved == ".." or resolved.startswith("../"):
            fail(f"unsafe link: {member.name} -> {member.linkname}")
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
        kept = [(m, p) for m, p in validated if not is_platform_metadata(p)]
        members = [member for member, _ in kept]
        paths = [path for _, path in kept]
        top_levels = {
            path.parts[0]
            for path in paths
            if path.parts
            and path.parts[0] != "."
            and path.parts[0] not in RUNTIME_COMPANIONS
        }
        if len(top_levels) != 1:
            fail("runtime archive must contain exactly one top-level directory")

        destination.mkdir()
        try:
            contents.extractall(destination, members=members, filter="data")
        except BaseException:
            remove_path(destination)
            raise

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

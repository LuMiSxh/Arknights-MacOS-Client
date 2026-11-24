# SPDX-License-Identifier: MPL-2.0

import tarfile
from io import BytesIO
from pathlib import Path

import pytest
from lib import extract_runtime


def add_file(archive: tarfile.TarFile, name: str, contents: bytes = b"") -> None:
    member = tarfile.TarInfo(name)
    member.size = len(contents)
    archive.addfile(member, BytesIO(contents))


def test_extracts_single_runtime_root(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "Runtime/bin/wine64", b"runtime")

    extracted = extract_runtime.extract(archive_path, tmp_path / "output")

    assert extracted.name == "Runtime"
    assert (extracted / "bin/wine64").read_bytes() == b"runtime"


def test_ignores_appledouble_metadata(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "._runtime", b"metadata")
        add_file(archive, "Runtime/bin/wine64", b"runtime")

    extracted = extract_runtime.extract(archive_path, tmp_path / "output")

    assert not (tmp_path / "output/._runtime").exists()
    assert (extracted / "bin/wine64").is_file()


def test_rejects_unknown_second_top_level_entry(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "Runtime/bin/wine64", b"runtime")
        add_file(archive, "Extra/file", b"extra")

    with pytest.raises(RuntimeError):
        extract_runtime.extract(archive_path, tmp_path / "output")


def test_rejects_parent_path(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "../escape", b"unsafe")

    with pytest.raises(RuntimeError):
        extract_runtime.extract(archive_path, tmp_path / "output")


def test_rejects_escaping_symbolic_link(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "Runtime/bin/wine64", b"runtime")
        link = tarfile.TarInfo("Runtime/bin/escape")
        link.type = tarfile.SYMTYPE
        link.linkname = "../../../outside"
        archive.addfile(link)

    with pytest.raises(RuntimeError):
        extract_runtime.extract(archive_path, tmp_path / "output")


def test_failed_extraction_removes_partial_destination(tmp_path: Path) -> None:
    archive_path = tmp_path / "runtime.tar.xz"
    destination = tmp_path / "output"
    with tarfile.open(archive_path, "w:xz") as archive:
        add_file(archive, "Runtime/bin/wine64", b"runtime")
        link = tarfile.TarInfo("Runtime/bin/missing-link")
        link.type = tarfile.LNKTYPE
        link.linkname = "Runtime/bin/missing-target"
        archive.addfile(link)

    with pytest.raises((KeyError, tarfile.ExtractError)):
        extract_runtime.extract(archive_path, destination)

    assert not destination.exists()

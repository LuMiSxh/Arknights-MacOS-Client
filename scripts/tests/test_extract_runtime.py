# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import tarfile
import tempfile
import unittest
from io import BytesIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import extract_runtime


def add_file(archive: tarfile.TarFile, name: str, contents: bytes = b"") -> None:
    member = tarfile.TarInfo(name)
    member.size = len(contents)
    archive.addfile(member, BytesIO(contents))


class RuntimeArchiveTests(unittest.TestCase):
    def test_extracts_single_runtime_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            archive_path = root / "runtime.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                add_file(archive, "runtime/bin/wine64", b"runtime")

            extracted = extract_runtime.extract(archive_path, root / "output")

            self.assertEqual(extracted.name, "runtime")
            self.assertEqual((extracted / "bin/wine64").read_bytes(), b"runtime")

    def test_ignores_appledouble_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            archive_path = root / "runtime.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                add_file(archive, "._runtime", b"metadata")
                add_file(archive, "runtime/bin/wine64", b"runtime")

            extracted = extract_runtime.extract(archive_path, root / "output")

            self.assertFalse((root / "output/._runtime").exists())
            self.assertTrue((extracted / "bin/wine64").is_file())

    def test_rejects_parent_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            archive_path = root / "runtime.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                add_file(archive, "../escape", b"unsafe")

            with self.assertRaises(RuntimeError):
                extract_runtime.extract(archive_path, root / "output")

    def test_rejects_escaping_symbolic_link(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            archive_path = root / "runtime.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                add_file(archive, "runtime/bin/wine64", b"runtime")
                link = tarfile.TarInfo("runtime/bin/escape")
                link.type = tarfile.SYMTYPE
                link.linkname = "../../../outside"
                archive.addfile(link)

            with self.assertRaises(RuntimeError):
                extract_runtime.extract(archive_path, root / "output")


if __name__ == "__main__":
    unittest.main()

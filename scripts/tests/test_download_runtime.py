# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import download_runtime


class DownloadRuntimeTests(unittest.TestCase):
    def test_accepts_complete_runtime_layout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            for relative in download_runtime.RUNTIME_COMMANDS:
                path = runtime / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
                path.chmod(0o755)
            metal = runtime / "lib/wine/x86_64-windows/winemetal.dll"
            metal.parent.mkdir(parents=True)
            metal.touch()
            for architecture in ("x64", "x32"):
                for library in download_runtime.DXMT_LIBRARIES:
                    path = runtime / "DXMT" / architecture / library
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.touch()
            (runtime / "bin/Arknights").symlink_to("wine64")

            self.assertTrue(download_runtime.runtime_is_valid(runtime))

    def test_rejects_wrong_launcher_link(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            (runtime / "bin").mkdir()
            (runtime / "bin/Arknights").symlink_to("wine")

            self.assertFalse(download_runtime.runtime_is_valid(runtime))


if __name__ == "__main__":
    unittest.main()

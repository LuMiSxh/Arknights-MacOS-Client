# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import download_runtime
from lib.common import PROJECT_DIR
from runtime_config import load_runtime_config


class DownloadRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.layout = load_runtime_config(PROJECT_DIR / "runtime.json").layout

    def create_runtime(self, runtime: Path) -> None:
        for relative in self.layout.required_paths:
            path = runtime / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        for relative in self.layout.executables:
            (runtime / relative).chmod(0o755)
        launcher = runtime / self.layout.launcher.path
        launcher.parent.mkdir(parents=True, exist_ok=True)
        launcher.symlink_to(self.layout.launcher.target)

    def test_accepts_complete_runtime_layout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            self.create_runtime(runtime)

            self.assertTrue(download_runtime.runtime_is_valid(runtime, self.layout))

    def test_rejects_wrong_launcher_link(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            self.create_runtime(runtime)
            launcher = runtime / self.layout.launcher.path
            launcher.unlink()
            launcher.symlink_to("wrong")

            self.assertFalse(download_runtime.runtime_is_valid(runtime, self.layout))

    def test_rejects_executable_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            self.create_runtime(runtime)
            executable = runtime / self.layout.executables[0]
            executable.unlink()
            executable.mkdir()

            self.assertFalse(download_runtime.runtime_is_valid(runtime, self.layout))

    def test_rejects_every_missing_declared_runtime_path(self) -> None:
        for missing in self.layout.required_paths:
            with self.subTest(path=missing), tempfile.TemporaryDirectory() as directory:
                runtime = Path(directory)
                self.create_runtime(runtime)
                (runtime / missing).unlink()

                self.assertFalse(
                    download_runtime.runtime_is_valid(runtime, self.layout)
                )


if __name__ == "__main__":
    unittest.main()

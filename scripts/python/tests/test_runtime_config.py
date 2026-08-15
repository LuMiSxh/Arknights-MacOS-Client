# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "runtime-config.py"
SPEC = importlib.util.spec_from_file_location("runtime_config", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
runtime_config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime_config)


class RuntimeConfigTests(unittest.TestCase):
    def valid_config(self) -> dict[str, object]:
        return {
            "schemaVersion": 1,
            "prefixRevision": 1,
            "runtime": {
                "name": "Test runtime",
                "url": "https://example.com/runtime.tar.gz",
                "sha256": "a" * 64,
            },
            "buildRecipe": {
                "url": "https://example.com/source.tar.gz",
                "sha256": "b" * 64,
            },
            "components": {
                "wine": "1",
                "dxmt": "1",
                "gstreamer": "1",
                "ffmpeg": "1",
                "moltenvk": "1",
                "wineGecko": "1",
            },
            "provenance": {
                "buildRepository": "https://example.com/build",
                "buildCommit": "c" * 40,
                "wineRepository": "https://example.com/wine",
                "wineCommit": "d" * 40,
                "dxmtRepository": "https://example.com/dxmt",
                "dxmtCommit": "e" * 40,
                "moltenvkRepository": "https://example.com/moltenvk",
                "moltenvkCommit": "f" * 40,
                "gstreamerRepository": "https://example.com/gstreamer",
                "gstreamerCommit": "a" * 40,
                "ffmpegRepository": "https://example.com/ffmpeg",
                "ffmpegCommit": "b" * 40,
                "wineGeckoRepository": "https://example.com/gecko",
                "wineGeckoCommit": "c" * 40,
                "nixpkgsRepository": "https://example.com/nixpkgs",
                "nixpkgsCommit": "e" * 40,
            },
        }

    def test_reads_nested_scalar(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "runtime.json"
            config.write_text(
                json.dumps({"runtime": {"url": "https://example.com/runtime.tar.gz"}}),
                encoding="utf-8",
            )
            self.assertEqual(
                runtime_config.read_value(config, "runtime.url"),
                "https://example.com/runtime.tar.gz",
            )

    def test_rejects_missing_value(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "runtime.json"
            config.write_text("{}", encoding="utf-8")
            with self.assertRaises(SystemExit):
                runtime_config.read_value(config, "runtime.url")

    def test_validates_complete_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "runtime.json"
            config.write_text(json.dumps(self.valid_config()), encoding="utf-8")
            runtime_config.validate_config(config)

    def test_rejects_invalid_checksum(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "runtime.json"
            value = self.valid_config()
            assert isinstance(value["runtime"], dict)
            value["runtime"]["sha256"] = "latest"
            config.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(SystemExit):
                runtime_config.validate_config(config)


if __name__ == "__main__":
    unittest.main()

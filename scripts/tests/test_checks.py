# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parents[1]))

import checks


class RunModeTests(unittest.TestCase):
    def test_check_all_runs_every_target_once(self) -> None:
        calls: list[str] = []
        with mock.patch.object(
            checks,
            "TARGETS",
            {
                "swift": (
                    lambda: calls.append("swift-check"),
                    lambda: calls.append("swift-format"),
                ),
                "scripts": (
                    lambda: calls.append("scripts-check"),
                    lambda: calls.append("scripts-format"),
                ),
            },
        ):
            checks.run_mode("check", "all")
        self.assertEqual(calls, ["swift-check", "scripts-check"])

    def test_format_single_target_only_calls_that_target(self) -> None:
        calls: list[str] = []
        with mock.patch.object(
            checks,
            "TARGETS",
            {
                "swift": (
                    lambda: calls.append("swift-check"),
                    lambda: calls.append("swift-format"),
                ),
                "shim": (
                    lambda: calls.append("shim-check"),
                    lambda: calls.append("shim-format"),
                ),
            },
        ):
            checks.run_mode("format", "shim")
        self.assertEqual(calls, ["shim-format"])


if __name__ == "__main__":
    unittest.main()

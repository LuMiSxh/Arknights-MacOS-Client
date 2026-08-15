# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import patch_wine_runtime


class WineRuntimePatchTests(unittest.TestCase):
    def test_changes_only_the_quit_shortcut(self) -> None:
        source = (
            b"before"
            + patch_wine_runtime.OPTION_COMMAND_Q
            + b"middle"
            + patch_wine_runtime.OPTION_COMMAND_Q
            + b"after"
        )

        patched, changed = patch_wine_runtime.patch_quit_shortcut(source)

        self.assertTrue(changed)
        self.assertEqual(patched.count(patch_wine_runtime.OPTION_COMMAND_Q), 1)
        self.assertEqual(patched.count(patch_wine_runtime.COMMAND_Q), 1)
        self.assertTrue(patched.startswith(b"before"))
        self.assertTrue(patched.endswith(b"after"))

    def test_accepts_an_already_patched_driver(self) -> None:
        source = (
            patch_wine_runtime.OPTION_COMMAND_Q
            + b"middle"
            + patch_wine_runtime.COMMAND_Q
        )

        patched, changed = patch_wine_runtime.patch_quit_shortcut(source)

        self.assertFalse(changed)
        self.assertEqual(patched, source)

    def test_rejects_an_unknown_driver_layout(self) -> None:
        with self.assertRaises(RuntimeError):
            patch_wine_runtime.patch_quit_shortcut(b"unknown")


if __name__ == "__main__":
    unittest.main()

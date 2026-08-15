# SPDX-License-Identifier: MPL-2.0

"""Apply the reviewed macOS integration patch to the pinned Wine runtime."""

from __future__ import annotations

import argparse
from pathlib import Path

OPTION_COMMAND_Q = b"\xba\x00\x00\x18\x00"
COMMAND_Q = b"\xba\x00\x00\x10\x00"


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def patch_quit_shortcut(data: bytes) -> tuple[bytes, bool]:
    option_command_offsets = [
        offset
        for offset in range(len(data))
        if data.startswith(OPTION_COMMAND_Q, offset)
    ]
    command_offsets = [
        offset for offset in range(len(data)) if data.startswith(COMMAND_Q, offset)
    ]

    if len(option_command_offsets) == 1 and len(command_offsets) == 1:
        return data, False
    if len(option_command_offsets) != 2 or command_offsets:
        fail("Wine menu layout does not match the reviewed runtime")

    quit_offset = option_command_offsets[1]
    patched = data[:quit_offset] + COMMAND_Q + data[quit_offset + len(COMMAND_Q) :]
    return patched, True


def patch_file(path: Path) -> bool:
    if not path.is_file():
        fail(f"Wine macOS driver not found: {path}")
    original = path.read_bytes()
    patched, changed = patch_quit_shortcut(original)
    if changed:
        path.write_bytes(patched)
    return changed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("driver", type=Path)
    arguments = parser.parse_args()
    changed = patch_file(arguments.driver.resolve())
    print("patched" if changed else "already patched")


if __name__ == "__main__":
    main()

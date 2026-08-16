# SPDX-License-Identifier: MPL-2.0

"""Shared cross-compilation and validation for compatibility components."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

from common import fail, output, run


def compile_windows(source: Path, destination: Path, *arguments: str) -> None:
    run(
        [
            sys.executable,
            "-m",
            "ziglang",
            "cc",
            "-target",
            "x86_64-windows-gnu",
            "-O2",
            source,
            *arguments,
            "-o",
            destination,
        ]
    )


def validate_pe(path: Path, *, dll: bool) -> None:
    data = path.read_bytes()
    if len(data) < 0x40 or data[:2] != b"MZ":
        fail(f"expected a Windows PE file: {path}")
    header_offset = struct.unpack_from("<I", data, 0x3C)[0]
    valid = (
        header_offset + 26 <= len(data)
        and data[header_offset : header_offset + 4] == b"PE\0\0"
        and struct.unpack_from("<H", data, header_offset + 4)[0] == 0x8664
        and struct.unpack_from("<H", data, header_offset + 24)[0] == 0x20B
    )
    if not valid:
        kind = "DLL" if dll else "executable"
        fail(f"expected a PE32+ x86-64 {kind}: {path}")


def validate_macho_x86_64(path: Path) -> None:
    architectures = output(["lipo", "-archs", path]).split()
    if architectures != ["x86_64"]:
        fail(f"expected an x86-64 Mach-O file: {path}")

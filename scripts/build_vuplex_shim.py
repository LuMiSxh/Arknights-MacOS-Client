#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["ziglang==0.15.1"]
# ///
# SPDX-License-Identifier: MPL-2.0

"""Cross-compile the Vuplex launcher shim and its userenv compatibility DLL."""

from __future__ import annotations

import argparse
import struct
import sys
import tempfile
from pathlib import Path

from common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    info,
    remove_path,
    run,
    run_main,
    success,
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


def compile_source(source: Path, output: Path, *arguments: str) -> None:
    run(
        [
            sys.executable,
            "-m",
            "ziglang",
            "cc",
            "-target",
            "x86_64-windows-gnu",
            "-O2",
            str(source),
            *arguments,
            "-o",
            str(output),
        ]
    )


def build(output: Path) -> tuple[Path, Path]:
    source_dir = PROJECT_DIR / "RuntimeSupport/VuplexShim"
    shim_source = source_dir / "VuplexShim.c"
    userenv_source = source_dir / "UserenvCompat.c"
    for source in (shim_source, userenv_source):
        if not source.is_file():
            fail(f"compatibility source not found: {source}")

    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    userenv_output = output.parent / "userenv.dll"
    with tempfile.TemporaryDirectory(
        prefix=".vuplex-build.", dir=output.parent
    ) as name:
        temporary = Path(name)
        shim_temporary = temporary / output.name
        userenv_temporary = temporary / userenv_output.name
        info("Compiling the Vuplex launcher shim")
        compile_source(
            shim_source,
            shim_temporary,
            "-Wl,/subsystem:windows",
            "-lshell32",
        )
        info("Compiling the userenv compatibility library")
        compile_source(
            userenv_source,
            userenv_temporary,
            "-shared",
            "-ladvapi32",
        )
        validate_pe(shim_temporary, dll=False)
        validate_pe(userenv_temporary, dll=True)
        remove_path(output)
        remove_path(userenv_output)
        shim_temporary.replace(output)
        userenv_temporary.replace(userenv_output)
    return output, userenv_output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=BUILD_DIR / "helpers/Vuplex WebView.vuplex",
    )
    arguments = parser.parse_args()
    shim, userenv = build(arguments.output)
    success(f"Built {shim.relative_to(PROJECT_DIR)}")
    success(f"Built {userenv.relative_to(PROJECT_DIR)}")


if __name__ == "__main__":
    run_main(main)

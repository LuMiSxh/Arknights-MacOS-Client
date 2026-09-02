# SPDX-License-Identifier: MPL-2.0

"""Shared paths, diagnostics, and process helpers for repository scripts."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from collections.abc import Callable, Iterable, Sequence
from pathlib import Path
from typing import NoReturn

from lib.console import child_output, error, styled

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
BUILD_DIR = PROJECT_DIR / ".build"
DIST_DIR = PROJECT_DIR / "dist"

VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


class ScriptError(RuntimeError):
    """A concise, expected command-line failure."""


def fail(message: str) -> NoReturn:
    raise ScriptError(message)


def require_command(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        fail(f"required command not found: {name}")
    return path


def require_file(path: Path) -> Path:
    if not path.is_file():
        fail(f"required file not found: {path}")
    return path


def require_directory(path: Path) -> Path:
    if not path.is_dir():
        fail(f"required directory not found: {path}")
    return path


def run(
    command: Sequence[str | Path],
    *,
    cwd: Path | None = None,
    capture: bool = False,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    arguments = [str(value) for value in command]
    try:
        if not capture:
            process = subprocess.Popen(
                arguments,
                cwd=cwd,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=environment,
            )
            assert process.stdout is not None
            for line in process.stdout:
                child_output(line.rstrip("\r\n"))
            returncode = process.wait()
            if returncode != 0:
                fail(f"command failed ({returncode}): {' '.join(arguments)}")
            return subprocess.CompletedProcess(arguments, returncode)
        return subprocess.run(
            arguments,
            cwd=cwd,
            check=True,
            text=True,
            capture_output=capture,
            env=environment,
        )
    except FileNotFoundError:
        fail(f"required command not found: {arguments[0]}")
    except subprocess.CalledProcessError as process_error:
        if capture:
            if process_error.stdout:
                print(process_error.stdout.rstrip())
            if process_error.stderr:
                print(process_error.stderr.rstrip(), file=sys.stderr)
        fail(f"command failed ({process_error.returncode}): {' '.join(arguments)}")


def output(command: Sequence[str | Path], *, cwd: Path | None = None) -> str:
    return run(command, cwd=cwd, capture=True).stdout.strip()


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink(missing_ok=True)
    elif path.exists():
        shutil.rmtree(path)


def safe_relative_path(value: object, error_message: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) > 240
        or value.startswith("/")
        or any(component in {"", ".", ".."} for component in value.split("/"))
        or re.fullmatch(r"[A-Za-z0-9._/+\-]+", value) is None
    ):
        raise ValueError(error_message)
    return value


def run_main[T](main: Callable[[], T]) -> None:
    try:
        main()
    except ScriptError as script_error:
        error(str(script_error))
        raise SystemExit(1) from None
    except KeyboardInterrupt:
        print(f"\n{styled('cancelled', '33;1')}", file=sys.stderr)
        raise SystemExit(130) from None


def require_commands(names: Iterable[str]) -> None:
    for name in names:
        require_command(name)

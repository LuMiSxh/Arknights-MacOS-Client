# SPDX-License-Identifier: MPL-2.0

"""Shared paths, diagnostics, and process helpers for repository scripts."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from collections.abc import Callable, Iterable, Sequence
from pathlib import Path
from typing import NoReturn, TypeVar

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
BUILD_DIR = PROJECT_DIR / ".build"
DIST_DIR = PROJECT_DIR / "dist"

_T = TypeVar("_T")
_USE_COLOR = sys.stderr.isatty() and os.environ.get("NO_COLOR") is None


class ScriptError(RuntimeError):
    """A concise, expected command-line failure."""


def _styled(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def info(message: str) -> None:
    print(f"{_styled('→', '36;1')} {message}", file=sys.stderr)


def success(message: str) -> None:
    print(f"{_styled('✓', '32;1')} {message}", file=sys.stderr)


def warning(message: str) -> None:
    print(f"{_styled('!', '33;1')} {message}", file=sys.stderr)


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
    except subprocess.CalledProcessError as error:
        if capture and error.stderr:
            print(error.stderr.rstrip(), file=sys.stderr)
        fail(f"command failed ({error.returncode}): {' '.join(arguments)}")


def output(command: Sequence[str | Path], *, cwd: Path | None = None) -> str:
    return run(command, cwd=cwd, capture=True).stdout.strip()


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink(missing_ok=True)
    elif path.exists():
        shutil.rmtree(path)


def run_main(main: Callable[[], _T]) -> None:
    try:
        main()
    except ScriptError as error:
        print(f"{_styled('error:', '31;1')} {error}", file=sys.stderr)
        raise SystemExit(1) from None
    except KeyboardInterrupt:
        print(f"\n{_styled('cancelled', '33;1')}", file=sys.stderr)
        raise SystemExit(130) from None


def require_commands(names: Iterable[str]) -> None:
    for name in names:
        require_command(name)

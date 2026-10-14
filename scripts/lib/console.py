# SPDX-License-Identifier: MPL-2.0

"""Plain status lines for repository scripts.

All output goes to stderr, so scripts that print a result to stdout (paths, values) stay
pipeable. `spinner` and `Progress` only print plain lines: CI logs are not terminals.
"""

from __future__ import annotations

import os
import sys
from collections.abc import Iterator
from contextlib import contextmanager

USE_COLOR = sys.stderr.isatty() and os.environ.get("NO_COLOR") is None
USE_UNICODE = "UTF" in (sys.stderr.encoding or "").upper()

_SYMBOLS = {
    "info": ("→", "->"),
    "child": ("↳", "->"),
    "success": ("✓", "OK"),
    "warning": ("!", "!!"),
    "error": ("✗", "XX"),
}
_CODES = {
    "info": "36;1",
    "child": "90",
    "success": "32;1",
    "warning": "33;1",
    "error": "31;1",
}


def styled(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if USE_COLOR else text


def _line(kind: str, message: str, indent: str = "") -> None:
    symbol = _SYMBOLS[kind][0 if USE_UNICODE else 1]
    print(f"{indent}{styled(symbol, _CODES[kind])} {message}", file=sys.stderr)


def info(message: str) -> None:
    _line("info", message)


def child_output(message: str) -> None:
    _line("child", message, indent="  ")


def success(message: str) -> None:
    _line("success", message)


def warning(message: str) -> None:
    _line("warning", message)


def error(message: str) -> None:
    _line("error", message)


@contextmanager
def spinner(message: str) -> Iterator[None]:
    """Print `message` once before the wrapped block runs."""
    info(message)
    yield


class Progress:
    """Byte-counted progress that prints a plain line at every 10 percent."""

    def __init__(self, message: str, total: int) -> None:
        self.message = message
        self.total = total
        self._next_report = 0.1
        info(message)

    def update(self, current: int) -> None:
        if self.total and current / self.total >= self._next_report:
            percentage = min(current / self.total * 100, 100)
            info(f"{self.message}: {percentage:.0f}% ({current / 1_048_576:,.0f} MiB)")
            self._next_report += 0.1

    def finish(self) -> None:
        """Keep the call site stable; plain lines need no cleanup."""

# SPDX-License-Identifier: MPL-2.0

"""Bounded HTTPS GET shared by the repository scripts that read remote data."""

from __future__ import annotations

import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Mapping
from dataclasses import dataclass


class HttpError(OSError):
    """A request that failed, left HTTPS, or returned more than the allowed bytes."""


@dataclass(frozen=True)
class Response:
    body: bytes
    content_type: str


def fetch(
    url: str,
    *,
    user_agent: str,
    timeout: float,
    max_bytes: int,
    headers: Mapping[str, str] | None = None,
) -> Response:
    """Return the body of an HTTPS GET, following redirects only to HTTPS URLs."""
    if urllib.parse.urlparse(url).scheme != "https":
        raise HttpError(f"remote URL must use HTTPS: {url}")
    request = urllib.request.Request(
        url, headers={"User-Agent": user_agent, **(headers or {})}
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if urllib.parse.urlparse(response.geturl()).scheme != "https":
                raise HttpError(f"request redirected to a non-HTTPS URL: {url}")
            content_type = (
                response.headers.get("Content-Type", "").split(";")[0].strip()
            )
            body = response.read(max_bytes + 1)
    except urllib.error.HTTPError as error:
        raise HttpError(f"request failed with status {error.code}: {url}") from error
    except urllib.error.URLError as error:
        raise HttpError(f"request failed: {url}: {error.reason}") from error
    if len(body) > max_bytes:
        raise HttpError(f"remote response exceeds {max_bytes} bytes: {url}")
    return Response(body, content_type)

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


class HttpsOnlyRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Refuse a redirect to a non-HTTPS target before the request follows it."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlparse(newurl).scheme != "https":
            raise HttpError(f"request redirected to a non-HTTPS URL: {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


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
    data: bytes | None = None,
    method: str | None = None,
) -> Response:
    """Return the body of an HTTPS request, following redirects only to HTTPS URLs."""
    if urllib.parse.urlparse(url).scheme != "https":
        raise HttpError(f"remote URL must use HTTPS: {url}")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"User-Agent": user_agent, **(headers or {})},
        method=method,
    )
    opener = urllib.request.build_opener(HttpsOnlyRedirectHandler())
    try:
        with opener.open(request, timeout=timeout) as response:
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

# SPDX-License-Identifier: MPL-2.0

"""Bounded GitHub API and unauthenticated asset-download client."""

from __future__ import annotations

import hashlib
import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from lib.common import ScriptError, fail

API_ROOT = "https://api.github.com"
API_VERSION = "2022-11-28"
MAXIMUM_API_BYTES = 8 * 1_024 * 1_024


class GitHubClient:
    def __init__(self, token: str | None = None) -> None:
        self.token = token

    def releases(self, repository: str) -> list[object]:
        value = self.repository_json(repository, "/releases?per_page=100")
        if not isinstance(value, list):
            fail("GitHub returned an invalid release list")
        return value

    def release(self, repository: str, tag: str) -> object:
        encoded_tag = urllib.parse.quote(tag, safe="")
        return self.repository_json(repository, f"/releases/tags/{encoded_tag}")

    def commit(self, repository: str, revision: str) -> dict[str, Any]:
        value = self.repository_json(
            repository, f"/commits/{urllib.parse.quote(revision, safe='')}"
        )
        if not isinstance(value, dict):
            fail(f"GitHub returned invalid commit metadata for {repository}")
        return value

    def compare(self, repository: str, old: str, new: str) -> dict[str, Any]:
        value = self.repository_json(repository, f"/compare/{old}...{new}")
        if not isinstance(value, dict):
            fail(f"GitHub returned invalid comparison metadata for {repository}")
        return value

    def file_at(self, repository: str, path: str, commit: str) -> str:
        endpoint = f"/contents/{path}?" + urllib.parse.urlencode({"ref": commit})
        return self.repository_bytes(
            repository,
            endpoint,
            accept="application/vnd.github.raw+json",
        ).decode("utf-8")

    def repository_json(
        self, repository: str, path: str, *, method: str = "GET", payload: object = None
    ) -> object:
        data = None if payload is None else json.dumps(payload).encode()
        response = self._request(
            f"{API_ROOT}/repos/{repository}{path}",
            method=method,
            data=data,
            authenticated=True,
            maximum_bytes=MAXIMUM_API_BYTES,
            accept="application/vnd.github+json",
        )
        return json.loads(response) if response else None

    def repository_bytes(self, repository: str, path: str, *, accept: str) -> bytes:
        return self._request(
            f"{API_ROOT}/repos/{repository}{path}",
            method="GET",
            authenticated=True,
            maximum_bytes=MAXIMUM_API_BYTES,
            accept=accept,
        )

    def download(self, url: str, maximum_bytes: int) -> bytes:
        return self._request(
            url,
            method="GET",
            authenticated=False,
            maximum_bytes=maximum_bytes,
            accept="application/octet-stream",
        )

    def hash_download(self, url: str, maximum_bytes: int) -> str:
        request = self._url_request(
            url, method="GET", authenticated=False, accept="application/octet-stream"
        )
        digest = hashlib.sha256()
        total = 0
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                while chunk := response.read(1_024 * 1_024):
                    total += len(chunk)
                    if total > maximum_bytes:
                        fail("runtime archive exceeds the verification size limit")
                    digest.update(chunk)
        except urllib.error.URLError as error:
            raise ScriptError(
                f"runtime archive download failed: {error.reason}"
            ) from None
        return digest.hexdigest()

    def artifact_archive(
        self, repository: str, artifact_id: int, maximum_bytes: int
    ) -> bytes:
        url = f"{API_ROOT}/repos/{repository}/actions/artifacts/{artifact_id}/zip"
        opener = urllib.request.build_opener(NoRedirectHandler())
        request = self._url_request(
            url, method="GET", authenticated=True, accept="application/vnd.github+json"
        )
        location: str | None = None
        try:
            with opener.open(request, timeout=20):
                pass
        except urllib.error.HTTPError as error:
            location = error.headers.get("Location")
            if error.code != 302 or not location:
                raise ScriptError(
                    f"GitHub artifact request failed with status {error.code}"
                ) from None
        if not location:
            fail("GitHub artifact download did not redirect")
        return self.download(location, maximum_bytes)

    def _request(
        self,
        url: str,
        *,
        method: str,
        authenticated: bool,
        maximum_bytes: int,
        data: bytes | None = None,
        accept: str,
    ) -> bytes:
        request = self._url_request(
            url,
            method=method,
            authenticated=authenticated,
            accept=accept,
            data=data,
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return bounded_read(response, maximum_bytes)
        except urllib.error.HTTPError as error:
            raise ScriptError(
                f"GitHub request failed with status {error.code}: {_endpoint_name(url)}"
            ) from None
        except urllib.error.URLError as error:
            raise ScriptError(
                f"GitHub request failed: {_endpoint_name(url)}: {error.reason}"
            ) from None

    def _url_request(
        self,
        url: str,
        *,
        method: str,
        authenticated: bool,
        accept: str,
        data: bytes | None = None,
    ) -> urllib.request.Request:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname:
            fail("remote URL must use HTTPS")
        headers = {
            "Accept": accept,
            "User-Agent": "arknights-runtime-monitor",
            "X-GitHub-Api-Version": API_VERSION,
        }
        if authenticated and self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return urllib.request.Request(url, data=data, method=method, headers=headers)


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        return None


def bounded_read(response, maximum_bytes: int) -> bytes:
    value = response.read(maximum_bytes + 1)
    if len(value) > maximum_bytes:
        fail(f"remote response exceeds {maximum_bytes} bytes")
    return value


def _endpoint_name(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return f"{parsed.hostname}{parsed.path}"

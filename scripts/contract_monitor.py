#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Summarize live reports and reconcile monitor-owned GitHub issues."""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

from lib.common import ScriptError, fail, run_main, success
from lib.contract_monitor import (
    MONITOR_LABEL,
    ContractAlertReconciler,
    ContractReport,
    MonitorIssue,
    report_markdown,
)

API_VERSION = "2022-11-28"
REPORT_ARTIFACT_NAME = "yostar-contract-report"
MAXIMUM_API_RESPONSE_BYTES = 4 * 1_024 * 1_024
MAXIMUM_REPORT_ARCHIVE_BYTES = 2 * 1_024 * 1_024
MAXIMUM_REPORT_BYTES = 1_024 * 1_024
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


class GitHubMonitorClient:
    def __init__(self, repository: str, token: str) -> None:
        if not REPOSITORY_PATTERN.fullmatch(repository):
            fail("GITHUB_REPOSITORY has an invalid value")
        self.repository = repository
        self.token = token

    def historical_reports(
        self, current_run_id: str, limit: int = 14
    ) -> list[ContractReport]:
        query = urllib.parse.urlencode(
            {"name": REPORT_ARTIFACT_NAME, "per_page": min(limit + 5, 100)}
        )
        payload = self._request("GET", f"/actions/artifacts?{query}")
        artifacts = payload.get("artifacts", []) if isinstance(payload, dict) else []
        reports: list[ContractReport] = []
        for artifact in artifacts:
            if not isinstance(artifact, dict) or artifact.get("expired") is True:
                continue
            workflow_run = artifact.get("workflow_run")
            run_id = (
                str(workflow_run.get("id")) if isinstance(workflow_run, dict) else ""
            )
            if run_id == current_run_id:
                continue
            try:
                archive = self._download_artifact(int(artifact["id"]))
                with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
                    report_info = zipped.getinfo("contract-report.json")
                    if report_info.file_size > MAXIMUM_REPORT_BYTES:
                        raise ValueError("contract report is too large")
                    report_value = json.loads(zipped.read(report_info))
                report = ContractReport.from_json(report_value)
            except (
                KeyError,
                TypeError,
                ValueError,
                json.JSONDecodeError,
                zipfile.BadZipFile,
            ):
                continue
            if report.trigger == "schedule":
                reports.append(report)
        return sorted(reports, key=lambda report: report.checked_at, reverse=True)[
            :limit
        ]

    def ensure_monitor_label(self) -> None:
        try:
            self._request(
                "POST",
                "/labels",
                {
                    "name": MONITOR_LABEL,
                    "color": "B60205",
                    "description": "Created and maintained by repository monitoring",
                },
            )
        except ScriptError as error:
            if "status 422" not in str(error):
                raise

    def list_monitor_issues(self) -> list[MonitorIssue]:
        query = urllib.parse.urlencode(
            {"state": "all", "labels": MONITOR_LABEL, "per_page": 100}
        )
        payload = self._request("GET", f"/issues?{query}")
        if not isinstance(payload, list):
            fail("GitHub returned an invalid issue list")
        return [
            MonitorIssue(
                number=int(item["number"]),
                state=str(item["state"]),
                title=str(item["title"]),
                body=str(item.get("body") or ""),
            )
            for item in payload
            if isinstance(item, dict) and "pull_request" not in item
        ]

    def create_issue(self, title: str, body: str) -> MonitorIssue:
        payload = self._request(
            "POST", "/issues", {"title": title, "body": body, "labels": [MONITOR_LABEL]}
        )
        if not isinstance(payload, dict):
            fail("GitHub returned an invalid created issue")
        return MonitorIssue(
            number=int(payload["number"]),
            state=str(payload["state"]),
            title=str(payload["title"]),
            body=str(payload.get("body") or ""),
        )

    def update_issue(
        self,
        number: int,
        *,
        body: str | None = None,
        state: str | None = None,
    ) -> None:
        payload: dict[str, str] = {}
        if body is not None:
            payload["body"] = body
        if state is not None:
            payload["state"] = state
            if state == "closed":
                payload["state_reason"] = "completed"
        self._request("PATCH", f"/issues/{number}", payload)

    def add_comment(self, number: int, body: str) -> None:
        self._request("POST", f"/issues/{number}/comments", {"body": body})

    def _request(self, method: str, path: str, payload: object | None = None) -> object:
        data = None if payload is None else json.dumps(payload).encode()
        response = self._open(method, path, data)
        return json.loads(response) if response else None

    def _download_artifact(self, artifact_id: int) -> bytes:
        path = f"/actions/artifacts/{artifact_id}/zip"
        opener = urllib.request.build_opener(NoRedirectHandler())
        request = self._github_request("GET", path, None)
        location: str | None = None
        try:
            with opener.open(request, timeout=20):
                pass
        except urllib.error.HTTPError as error:
            location = error.headers.get("Location")
            if error.code != 302 or not location:
                raise ScriptError(
                    f"GitHub API GET {path} failed with status {error.code}"
                ) from None
        if not location:
            fail("GitHub artifact download did not redirect")
        parsed = urllib.parse.urlparse(location)
        if parsed.scheme != "https" or not parsed.hostname:
            fail("GitHub returned an invalid artifact download URL")
        download = urllib.request.Request(
            location,
            headers={"User-Agent": "arknights-contract-monitor"},
        )
        try:
            with urllib.request.urlopen(download, timeout=20) as response:
                return _bounded_read(response, MAXIMUM_REPORT_ARCHIVE_BYTES)
        except urllib.error.URLError as error:
            raise ScriptError(f"artifact download failed: {error.reason}") from None

    def _open(self, method: str, path: str, data: bytes | None) -> bytes:
        request = self._github_request(method, path, data)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return _bounded_read(response, MAXIMUM_API_RESPONSE_BYTES)
        except urllib.error.HTTPError as error:
            raise ScriptError(
                f"GitHub API {method} {path} failed with status {error.code}"
            ) from None
        except urllib.error.URLError as error:
            raise ScriptError(
                f"GitHub API {method} {path} failed: {error.reason}"
            ) from None

    def _github_request(
        self, method: str, path: str, data: bytes | None
    ) -> urllib.request.Request:
        return urllib.request.Request(
            f"https://api.github.com/repos/{self.repository}{path}",
            data=data,
            method=method,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "X-GitHub-Api-Version": API_VERSION,
                "User-Agent": "arknights-contract-monitor",
            },
        )


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        return None


def _bounded_read(response, maximum_bytes: int) -> bytes:
    data = response.read(maximum_bytes + 1)
    if len(data) > maximum_bytes:
        fail(f"remote response exceeds {maximum_bytes} bytes")
    return data


def load_report(path: Path) -> ContractReport:
    try:
        return ContractReport.from_json(json.loads(path.read_text()))
    except (OSError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise ScriptError(f"invalid contract report at {path}: {error}") from None


def summarize(report_path: Path, output_path: Path | None) -> None:
    markdown = report_markdown(load_report(report_path))
    if output_path:
        with output_path.open("a") as output:
            output.write(markdown)
    else:
        print(markdown, end="")


def reconcile(report_path: Path) -> None:
    repository = os.environ.get("GITHUB_REPOSITORY") or fail(
        "GITHUB_REPOSITORY is required"
    )
    token = os.environ.get("GITHUB_TOKEN") or fail("GITHUB_TOKEN is required")
    run_id = os.environ.get("GITHUB_RUN_ID") or fail("GITHUB_RUN_ID is required")
    current = load_report(report_path)
    if current.trigger != "schedule":
        success("manual contract report does not mutate GitHub issues")
        return
    client = GitHubMonitorClient(repository, token)
    history = client.historical_reports(run_id)
    actions = ContractAlertReconciler(client).reconcile(current, history)
    success(", ".join(actions) if actions else "contract alert state unchanged")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    summary_parser = commands.add_parser("summarize")
    summary_parser.add_argument("report", type=Path)
    summary_parser.add_argument("--output", type=Path)
    reconcile_parser = commands.add_parser("reconcile")
    reconcile_parser.add_argument("report", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "summarize":
        summarize(arguments.report, arguments.output)
    else:
        reconcile(arguments.report)


if __name__ == "__main__":
    run_main(main)

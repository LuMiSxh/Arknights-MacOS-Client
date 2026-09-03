# SPDX-License-Identifier: MPL-2.0

"""Shared GitHub issue and retained-report support for repository monitors."""

from __future__ import annotations

import io
import json
import re
import urllib.parse
import zipfile
from collections.abc import Callable
from typing import Any, Protocol

from lib.common import ScriptError, fail
from lib.github_client import MAXIMUM_API_BYTES, GitHubClient

AUTOMATED_LABEL = "automated"
MAXIMUM_REPORT_ARCHIVE_BYTES = 2 * 1_024 * 1_024
MAXIMUM_REPORT_BYTES = 1_024 * 1_024
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


class Issue(Protocol):
    number: int
    state: str
    body: str


class Report(Protocol):
    checked_at: str
    trigger: str


class GitHubIssueStore[IssueT: Issue]:
    def __init__(
        self,
        client: GitHubClient,
        repository: str,
        *,
        issue_factory: Callable[[dict[str, Any]], IssueT],
        label_color: str,
        label_description: str,
        maximum_api_bytes: int = MAXIMUM_API_BYTES,
    ) -> None:
        validate_repository(repository)
        self.client = client
        self.repository = repository
        self.issue_factory = issue_factory
        self.label_color = label_color
        self.label_description = label_description
        self.maximum_api_bytes = maximum_api_bytes

    def ensure_label(self) -> None:
        try:
            self.client.repository_json(
                self.repository,
                "/labels",
                method="POST",
                payload={
                    "name": AUTOMATED_LABEL,
                    "color": self.label_color,
                    "description": self.label_description,
                },
                maximum_bytes=self.maximum_api_bytes,
            )
        except ScriptError as error:
            if "status 422" not in str(error):
                raise

    def list_issues(self) -> list[IssueT]:
        query = urllib.parse.urlencode(
            {"state": "all", "labels": AUTOMATED_LABEL, "per_page": 100}
        )
        value = self.client.repository_json(
            self.repository,
            f"/issues?{query}",
            maximum_bytes=self.maximum_api_bytes,
        )
        if not isinstance(value, list):
            fail("GitHub returned an invalid automated issue list")
        return [
            self.issue_factory(item)
            for item in value
            if isinstance(item, dict) and "pull_request" not in item
        ]

    def create_issue(self, title: str, body: str) -> IssueT:
        value = self.client.repository_json(
            self.repository,
            "/issues",
            method="POST",
            payload={"title": title, "body": body, "labels": [AUTOMATED_LABEL]},
            maximum_bytes=self.maximum_api_bytes,
        )
        if not isinstance(value, dict):
            fail("GitHub returned invalid created issue metadata")
        return self.issue_factory(value)

    def update_issue(
        self, number: int, *, body: str | None = None, state: str | None = None
    ) -> None:
        payload: dict[str, str] = {}
        if body is not None:
            payload["body"] = body
        if state is not None:
            payload["state"] = state
            if state == "closed":
                payload["state_reason"] = "completed"
        self.client.repository_json(
            self.repository,
            f"/issues/{number}",
            method="PATCH",
            payload=payload,
            maximum_bytes=self.maximum_api_bytes,
        )

    def add_comment(self, number: int, body: str) -> None:
        self.client.repository_json(
            self.repository,
            f"/issues/{number}/comments",
            method="POST",
            payload={"body": body},
            maximum_bytes=self.maximum_api_bytes,
        )


def historical_reports[ReportT: Report](
    client: GitHubClient,
    repository: str,
    current_run_id: str,
    *,
    artifact_name: str,
    report_filename: str,
    report_factory: Callable[[object], ReportT],
    limit: int,
    maximum_api_bytes: int = MAXIMUM_API_BYTES,
) -> list[ReportT]:
    validate_repository(repository)
    query = urllib.parse.urlencode(
        {"name": artifact_name, "per_page": min(limit + 5, 100)}
    )
    value = client.repository_json(
        repository,
        f"/actions/artifacts?{query}",
        maximum_bytes=maximum_api_bytes,
    )
    artifacts = value.get("artifacts", []) if isinstance(value, dict) else []
    reports: list[ReportT] = []
    for artifact in artifacts:
        if not isinstance(artifact, dict) or artifact.get("expired") is True:
            continue
        workflow_run = artifact.get("workflow_run")
        run_id = str(workflow_run.get("id")) if isinstance(workflow_run, dict) else ""
        if run_id == current_run_id:
            continue
        try:
            archive = client.artifact_archive(
                repository, int(artifact["id"]), MAXIMUM_REPORT_ARCHIVE_BYTES
            )
            with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
                info = zipped.getinfo(report_filename)
                if info.file_size > MAXIMUM_REPORT_BYTES:
                    raise ValueError("monitor report is too large")
                report = report_factory(json.loads(zipped.read(info)))
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
    return sorted(reports, key=lambda item: item.checked_at, reverse=True)[:limit]


def validate_repository(repository: str) -> None:
    if REPOSITORY_PATTERN.fullmatch(repository) is None:
        fail("GITHUB_REPOSITORY has an invalid value")

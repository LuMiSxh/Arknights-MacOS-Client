# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import io
import json
import zipfile
from dataclasses import dataclass

import pytest
from lib.common import ScriptError
from lib.github_monitor import GitHubIssueStore, historical_reports


@dataclass(frozen=True)
class FixtureIssue:
    number: int
    state: str
    body: str


@dataclass(frozen=True)
class FixtureReport:
    checked_at: str
    trigger: str

    @classmethod
    def from_json(cls, value: object) -> FixtureReport:
        if not isinstance(value, dict):
            raise TypeError("report must be an object")
        return cls(checked_at=str(value["checkedAt"]), trigger=str(value["trigger"]))


def issue_from_json(value: dict[str, object]) -> FixtureIssue:
    return FixtureIssue(
        number=int(value["number"]),
        state=str(value["state"]),
        body=str(value.get("body") or ""),
    )


def test_issue_store_filters_pull_requests_and_preserves_mutation_payloads() -> None:
    client = FakeGitHubClient()
    client.responses["GET /issues?state=all&labels=automated&per_page=100"] = [
        {"number": 4, "state": "open", "body": "incident"},
        {"number": 5, "state": "open", "body": "PR", "pull_request": {}},
    ]
    store = GitHubIssueStore(
        client,
        "owner/repo",
        issue_factory=issue_from_json,
        label_color="6E7781",
        label_description="Automated",
    )

    assert store.list_issues() == [FixtureIssue(4, "open", "incident")]
    store.update_issue(4, body="recovered", state="closed")

    assert client.requests[-1] == (
        "PATCH",
        "/issues/4",
        {"body": "recovered", "state": "closed", "state_reason": "completed"},
    )


def test_history_filters_irrelevant_and_malformed_artifacts() -> None:
    client = FakeGitHubClient()
    client.responses["GET /actions/artifacts?name=fixture&per_page=9"] = {
        "artifacts": [
            {"id": 1, "workflow_run": {"id": 99}},
            {"id": 2, "expired": True, "workflow_run": {"id": 2}},
            {"id": 3, "workflow_run": {"id": 3}},
            {"id": 4, "workflow_run": {"id": 4}},
            {"id": 5, "workflow_run": {"id": 5}},
        ]
    }
    client.artifacts[3] = report_archive("2026-08-20T00:00:00Z", "schedule")
    client.artifacts[4] = report_archive("2026-08-21T00:00:00Z", "workflow_dispatch")
    client.artifacts[5] = b"not a zip"

    reports = historical_reports(
        client,
        "owner/repo",
        "99",
        artifact_name="fixture",
        report_filename="report.json",
        report_factory=FixtureReport.from_json,
        limit=4,
    )

    assert reports == [FixtureReport("2026-08-20T00:00:00Z", "schedule")]


def test_issue_store_rejects_untrusted_repository_values() -> None:
    with pytest.raises(ScriptError, match="invalid value"):
        GitHubIssueStore(
            FakeGitHubClient(),
            "owner/repo?unexpected=true",
            issue_factory=issue_from_json,
            label_color="6E7781",
            label_description="Automated",
        )


def report_archive(checked_at: str, trigger: str) -> bytes:
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as archive:
        archive.writestr(
            "report.json",
            json.dumps({"checkedAt": checked_at, "trigger": trigger}),
        )
    return stream.getvalue()


class FakeGitHubClient:
    def __init__(self) -> None:
        self.responses: dict[str, object] = {}
        self.artifacts: dict[int, bytes] = {}
        self.requests: list[tuple[str, str, object]] = []

    def repository_json(
        self,
        repository: str,
        path: str,
        *,
        method: str = "GET",
        payload: object = None,
        maximum_bytes: int,
    ) -> object:
        assert repository == "owner/repo"
        assert maximum_bytes > 0
        self.requests.append((method, path, payload))
        return self.responses.get(f"{method} {path}")

    def artifact_archive(
        self, repository: str, artifact_id: int, maximum_bytes: int
    ) -> bytes:
        assert repository == "owner/repo"
        value = self.artifacts[artifact_id]
        assert len(value) <= maximum_bytes
        return value

# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from dataclasses import replace

from lib.runtime_monitor import (
    RuntimeAlertReconciler,
    RuntimeCandidate,
    RuntimeIncident,
    RuntimeMonitorIssue,
    RuntimeMonitorReport,
)

CANDIDATE_COMMIT = "b" * 40
CANDIDATE_DIGEST = "2" * 64


def test_newer_candidate_updates_the_existing_monitor_issue() -> None:
    first = monitor_report(candidate=candidate("4.5.125", CANDIDATE_DIGEST))
    assert first.candidate is not None
    issue = monitor_issue("candidate", first.candidate.condition, state="open")
    store = FakeIssueStore([issue])
    newer = monitor_report(candidate=candidate("4.5.126", "3" * 64))

    actions = RuntimeAlertReconciler(store).reconcile(newer, [first])

    assert actions == ["updated runtime candidate"]
    assert len(store.issues) == 1
    assert "`4.5.126`" in store.issues[0].body
    assert len(store.comments) == 1


def test_same_closed_candidate_remains_a_maintainer_decision() -> None:
    report = monitor_report(candidate=candidate("4.5.125", CANDIDATE_DIGEST))
    assert report.candidate is not None
    issue = monitor_issue("candidate", report.candidate.condition, state="closed")
    store = FakeIssueStore([issue])

    actions = RuntimeAlertReconciler(store).reconcile(report, [])

    assert actions == []
    assert store.issues[0].state == "closed"


def test_availability_incident_reuses_issue_and_requires_sustained_recovery() -> None:
    incident = RuntimeIncident("pinned-release", "HTTP 404")
    failing = monitor_report(incidents=(incident,))
    store = FakeIssueStore()
    reconciler = RuntimeAlertReconciler(store)

    assert reconciler.reconcile(failing, []) == ["opened runtime availability incident"]
    assert len(store.issues) == 1

    first_healthy = monitor_report(run=2)
    assert reconciler.reconcile(first_healthy, [failing]) == []
    assert store.issues[0].state == "open"

    second_healthy = monitor_report(run=3)
    assert reconciler.reconcile(second_healthy, [first_healthy, failing]) == [
        "closed runtime availability incident"
    ]
    assert store.issues[0].state == "closed"

    assert reconciler.reconcile(failing, [second_healthy, first_healthy]) == [
        "reopened runtime availability incident"
    ]
    assert len(store.issues) == 1
    assert store.issues[0].state == "open"


def candidate(version: str, digest: str) -> RuntimeCandidate:
    return RuntimeCandidate(
        pinned_version="4.5.118",
        version=version,
        digest=digest,
        build_commit=CANDIDATE_COMMIT,
        impact="used-components",
        changed_pins=(("WINECX_COMMIT", "a" * 40, CANDIDATE_COMMIT),),
        change_areas=(("WineCX", "changed"),),
        commit_summaries=("chore: bump winecx",),
        changed_files=(".github/workflows/build.yml",),
    )


def monitor_report(
    *,
    run: int = 1,
    candidate: RuntimeCandidate | None = None,
    incidents: tuple[RuntimeIncident, ...] = (),
) -> RuntimeMonitorReport:
    return RuntimeMonitorReport(
        checked_at=f"2026-08-{run:02d}T05:23:00Z",
        trigger="schedule",
        run_id=str(run),
        run_url=f"https://github.com/example/repo/actions/runs/{run}",
        pinned_version="4.5.118",
        candidate=candidate,
        incidents=incidents,
        archive_verification="not-requested",
    )


def monitor_issue(key: str, condition: str, *, state: str) -> RuntimeMonitorIssue:
    return RuntimeMonitorIssue(
        number=1,
        state=state,
        body=(
            f"<!-- runtime-monitor:{key} -->\n<!-- monitor-condition:{condition} -->"
        ),
    )


class FakeIssueStore:
    def __init__(self, issues: list[RuntimeMonitorIssue] | None = None) -> None:
        self.issues = list(issues or [])
        self.comments: list[tuple[int, str]] = []

    def ensure_label(self) -> None:
        pass

    def list_issues(self) -> list[RuntimeMonitorIssue]:
        return list(self.issues)

    def create_issue(self, title: str, body: str) -> RuntimeMonitorIssue:
        issue = RuntimeMonitorIssue(len(self.issues) + 1, "open", body)
        self.issues.append(issue)
        return issue

    def update_issue(
        self, number: int, *, body: str | None = None, state: str | None = None
    ) -> None:
        index = next(
            index for index, issue in enumerate(self.issues) if issue.number == number
        )
        issue = self.issues[index]
        self.issues[index] = replace(
            issue,
            body=body if body is not None else issue.body,
            state=state if state is not None else issue.state,
        )

    def add_comment(self, number: int, body: str) -> None:
        self.comments.append((number, body))

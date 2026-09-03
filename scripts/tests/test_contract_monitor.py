# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from dataclasses import replace

import pytest
from lib.contract_monitor import (
    MONITOR_MARKER_PREFIX,
    ContractAlertReconciler,
    ContractCheck,
    ContractReport,
    MonitorIssue,
    report_markdown,
)


def test_report_rejects_duplicate_checks() -> None:
    value = report_value("failed")
    value["checks"].append(value["checks"][0].copy())

    with pytest.raises(ValueError, match="duplicate checks"):
        ContractReport.from_json(value)


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("region", "china", "unsupported contract region"),
        ("contract", "payload", "unsupported contract category"),
        ("summary", "line one\nline two", "short single line"),
        ("summary", "version 1|2", "short single line"),
        ("summary", "<img src=x>", "short single line"),
    ],
)
def test_report_rejects_untrusted_check_metadata(
    field: str, value: str, message: str
) -> None:
    report = report_value("failed")
    checks = report["checks"]
    assert isinstance(checks, list)
    checks[0][field] = value

    with pytest.raises(ValueError, match=message):
        ContractReport.from_json(report)


def test_markdown_renders_health_and_summary() -> None:
    report = make_report("healthy", summary="version 1.2")

    markdown = report_markdown(report)

    assert "| healthy |" in markdown
    assert "version 1.2" in markdown


def test_first_failure_does_not_open_an_issue() -> None:
    store = FakeIssueStore()

    actions = ContractAlertReconciler(store).reconcile(
        make_report("failed", run=2),
        [make_report("healthy", run=1)],
    )

    assert actions == []
    assert store.issues == []
    assert store.label_ensured == 0


def test_second_consecutive_failure_opens_one_sanitized_issue() -> None:
    store = FakeIssueStore()
    current = make_report("failed", run=3, summary="HTTP 503")

    actions = ContractAlertReconciler(store).reconcile(
        current,
        [make_report("failed", run=2), make_report("healthy", run=1)],
    )

    assert actions == ["opened global:manifest"]
    assert store.label_ensured == 1
    assert len(store.issues) == 1
    issue = store.issues[0]
    assert issue.key == "global:manifest"
    assert "2026-08-02T04:23:00Z" in issue.body
    assert "2026-08-03T04:23:00Z" in issue.body
    assert "2026-08-01T04:23:00Z" in issue.body
    assert "HTTP 503" in issue.body
    assert "Authorization" not in issue.body


def test_unchanged_failure_updates_timestamp_without_comment_spam() -> None:
    current = make_report("failed", run=4, summary="HTTP 503")
    issue = monitor_issue(current.checks[0], state="open")
    store = FakeIssueStore([issue])

    actions = ContractAlertReconciler(store).reconcile(
        current,
        [make_report("failed", run=3, summary="HTTP 503")],
    )

    assert actions == []
    assert store.comments == []
    assert "2026-08-04T04:23:00Z" in store.issues[0].body


def test_changed_failure_adds_one_comment() -> None:
    old = make_report("failed", run=2, summary="HTTP 503")
    issue = monitor_issue(old.checks[0], state="open")
    store = FakeIssueStore([issue])

    actions = ContractAlertReconciler(store).reconcile(
        make_report("failed", run=3, summary="manifest decoding failed"),
        [old],
    )

    assert actions == ["updated global:manifest"]
    assert len(store.comments) == 1
    assert "manifest decoding failed" in store.comments[0][1]


def test_recovery_requires_two_consecutive_healthy_reports() -> None:
    failed = make_report("failed", run=2)
    issue = monitor_issue(failed.checks[0], state="open")
    store = FakeIssueStore([issue])
    reconciler = ContractAlertReconciler(store)

    assert reconciler.reconcile(make_report("healthy", run=3), [failed]) == []
    assert store.issues[0].state == "open"

    actions = reconciler.reconcile(
        make_report("healthy", run=4),
        [make_report("healthy", run=3), failed],
    )

    assert actions == ["closed global:manifest"]
    assert store.issues[0].state == "closed"
    assert "considered recovered" in store.comments[-1][1]


def test_repeated_failure_reopens_monitor_owned_issue() -> None:
    failed = make_report("failed", run=2)
    issue = monitor_issue(failed.checks[0], state="closed")
    store = FakeIssueStore([issue])

    actions = ContractAlertReconciler(store).reconcile(
        make_report("failed", run=4),
        [make_report("failed", run=3)],
    )

    assert actions == ["reopened global:manifest"]
    assert store.issues[0].state == "open"


def test_blocked_checks_and_manual_history_do_not_mutate_issues() -> None:
    store = FakeIssueStore()
    reconciler = ContractAlertReconciler(store)

    assert reconciler.reconcile(make_report("blocked", run=3), []) == []
    assert (
        reconciler.reconcile(
            make_report("failed", run=3),
            [make_report("failed", run=2, trigger="workflow_dispatch")],
        )
        == []
    )


def report_value(status: str) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "checkedAt": "2026-08-01T04:23:00Z",
        "trigger": "schedule",
        "runID": "1",
        "runURL": "https://github.com/example/repo/actions/runs/1",
        "checks": [
            {
                "region": "global",
                "contract": "manifest",
                "status": status,
                "summary": "fixture result",
            }
        ],
    }


def make_report(
    status: str,
    *,
    run: int = 1,
    trigger: str = "schedule",
    summary: str = "fixture result",
) -> ContractReport:
    value = report_value(status)
    value.update(
        {
            "checkedAt": f"2026-08-{run:02d}T04:23:00Z",
            "trigger": trigger,
            "runID": str(run),
            "runURL": f"https://github.com/example/repo/actions/runs/{run}",
        }
    )
    checks = value["checks"]
    assert isinstance(checks, list)
    checks[0]["summary"] = summary
    return ContractReport.from_json(value)


def monitor_issue(check: ContractCheck, *, state: str) -> MonitorIssue:
    return MonitorIssue(
        number=1,
        state=state,
        title="Monitor issue",
        body=(
            f"<!-- {MONITOR_MARKER_PREFIX}{check.key} -->\n"
            f"<!-- monitor-condition:{check.condition} -->"
        ),
    )


class FakeIssueStore:
    def __init__(self, issues: list[MonitorIssue] | None = None) -> None:
        self.issues = list(issues or [])
        self.comments: list[tuple[int, str]] = []
        self.label_ensured = 0

    def ensure_label(self) -> None:
        self.label_ensured += 1

    def list_issues(self) -> list[MonitorIssue]:
        return list(self.issues)

    def create_issue(self, title: str, body: str) -> MonitorIssue:
        issue = MonitorIssue(
            number=len(self.issues) + 1, state="open", title=title, body=body
        )
        self.issues.append(issue)
        return issue

    def update_issue(
        self,
        number: int,
        *,
        body: str | None = None,
        state: str | None = None,
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

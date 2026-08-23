# SPDX-License-Identifier: MPL-2.0

"""Pure report and alert-policy logic for the Yostar contract monitor."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol
from urllib.parse import urlparse

REPORT_SCHEMA_VERSION = 1
MONITOR_LABEL = "automated-monitor"
MONITOR_MARKER_PREFIX = "arknights-contract-monitor:"
CONSECUTIVE_FAILURES_TO_ALERT = 2
CONSECUTIVE_SUCCESSES_TO_RECOVER = 2
SUPPORTED_REGIONS = {"global", "japan", "korea"}
SUPPORTED_CONTRACTS = {
    "branding",
    "game-configuration",
    "cdn",
    "manifest-location",
    "manifest",
}
SAFE_SUMMARY_PATTERN = re.compile(r"^[A-Za-z0-9 .,_:/()'&+\-]+$")


@dataclass(frozen=True)
class ContractCheck:
    region: str
    contract: str
    status: str
    summary: str

    @property
    def key(self) -> str:
        return f"{self.region}:{self.contract}"

    @property
    def condition(self) -> str:
        value = f"{self.status}\0{self.summary}".encode()
        return hashlib.sha256(value).hexdigest()[:16]


@dataclass(frozen=True)
class ContractReport:
    checked_at: str
    trigger: str
    run_id: str
    run_url: str
    checks: tuple[ContractCheck, ...]

    @classmethod
    def from_json(cls, value: object) -> ContractReport:
        if (
            not isinstance(value, dict)
            or value.get("schemaVersion") != REPORT_SCHEMA_VERSION
        ):
            raise ValueError("unsupported contract report schema")
        checks_value = value.get("checks")
        if not isinstance(checks_value, list):
            raise TypeError("contract report checks must be a list")
        checks = tuple(_parse_check(item) for item in checks_value)
        if len({check.key for check in checks}) != len(checks):
            raise ValueError("contract report contains duplicate checks")
        checked_at = _required_string(value, "checkedAt")
        try:
            datetime.fromisoformat(checked_at)
        except ValueError:
            raise ValueError("contract report checkedAt must be ISO-8601") from None
        trigger = _required_string(value, "trigger")
        if trigger not in {"schedule", "workflow_dispatch", "local"}:
            raise ValueError(f"unsupported contract report trigger: {trigger}")
        run_url = _required_string(value, "runURL")
        parsed_run_url = urlparse(run_url)
        if run_url != "local" and (
            parsed_run_url.scheme != "https" or parsed_run_url.hostname != "github.com"
        ):
            raise ValueError("contract report runURL must target github.com")
        return cls(
            checked_at=checked_at,
            trigger=trigger,
            run_id=_required_string(value, "runID"),
            run_url=run_url,
            checks=checks,
        )

    def check_by_key(self, key: str) -> ContractCheck | None:
        return next((check for check in self.checks if check.key == key), None)


@dataclass(frozen=True)
class MonitorIssue:
    number: int
    state: str
    title: str
    body: str

    @property
    def key(self) -> str | None:
        prefix = f"<!-- {MONITOR_MARKER_PREFIX}"
        for line in self.body.splitlines():
            if line.startswith(prefix) and line.endswith(" -->"):
                return line.removeprefix(prefix).removesuffix(" -->")
        return None

    @property
    def condition(self) -> str | None:
        prefix = "<!-- monitor-condition:"
        for line in self.body.splitlines():
            if line.startswith(prefix) and line.endswith(" -->"):
                return line.removeprefix(prefix).removesuffix(" -->")
        return None


class MonitorIssueStore(Protocol):
    def ensure_monitor_label(self) -> None: ...

    def list_monitor_issues(self) -> list[MonitorIssue]: ...

    def create_issue(self, title: str, body: str) -> MonitorIssue: ...

    def update_issue(
        self,
        number: int,
        *,
        body: str | None = None,
        state: str | None = None,
    ) -> None: ...

    def add_comment(self, number: int, body: str) -> None: ...


class ContractAlertReconciler:
    def __init__(self, store: MonitorIssueStore) -> None:
        self.store = store

    def reconcile(
        self,
        current: ContractReport,
        history: list[ContractReport],
    ) -> list[str]:
        scheduled_history = [
            report for report in history if report.trigger == "schedule"
        ]
        issues: dict[str, MonitorIssue] = {}
        for issue in self.store.list_monitor_issues():
            key = issue.key
            if key is None:
                continue
            existing = issues.get(key)
            if existing is None or (issue.state == "open" and existing.state != "open"):
                issues[key] = issue
        actions: list[str] = []

        for check in current.checks:
            previous_reports = [
                report
                for report in scheduled_history
                if report.check_by_key(check.key) is not None
            ]
            issue = issues.get(check.key)
            if check.status == "failed":
                action = self._reconcile_failure(
                    current, check, previous_reports, issue
                )
            elif check.status == "healthy":
                action = self._reconcile_success(
                    current, check, previous_reports, issue
                )
            else:
                action = None
            if action:
                actions.append(action)

        return actions

    def _reconcile_failure(
        self,
        current: ContractReport,
        check: ContractCheck,
        previous_reports: list[ContractReport],
        issue: MonitorIssue | None,
    ) -> str | None:
        previous = [
            historical
            for report in previous_reports
            if (historical := report.check_by_key(check.key)) is not None
        ]
        if issue is None and not _has_consecutive_status(
            check,
            previous,
            "failed",
            CONSECUTIVE_FAILURES_TO_ALERT,
        ):
            return None

        self.store.ensure_monitor_label()
        failure_reports = _consecutive_reports(
            current, previous_reports, "failed", check.key
        )
        first_failure = failure_reports[-1]
        last_success = _first_report_with_status(previous_reports, "healthy", check.key)
        body = _failure_body(
            check=check,
            first_failure=first_failure,
            latest_failure=current,
            last_success=last_success,
        )

        if issue is None:
            self.store.create_issue(_issue_title(check), body)
            return f"opened {check.key}"

        if issue.state == "closed":
            self.store.update_issue(issue.number, body=body, state="open")
            self.store.add_comment(
                issue.number,
                f"The contract failed in two consecutive scheduled checks again.\n\n"
                f"Latest run: {current.run_url}",
            )
            return f"reopened {check.key}"

        self.store.update_issue(issue.number, body=body)
        if issue.condition != check.condition:
            self.store.add_comment(
                issue.number,
                f"The observed failure changed: `{check.summary}`\n\n"
                f"Latest run: {current.run_url}",
            )
            return f"updated {check.key}"
        return None

    def _reconcile_success(
        self,
        current: ContractReport,
        check: ContractCheck,
        previous_reports: list[ContractReport],
        issue: MonitorIssue | None,
    ) -> str | None:
        if issue is None or issue.state != "open":
            return None
        previous = [
            historical
            for report in previous_reports
            if (historical := report.check_by_key(check.key)) is not None
        ]
        if not _has_consecutive_status(
            check,
            previous,
            "healthy",
            CONSECUTIVE_SUCCESSES_TO_RECOVER,
        ):
            return None

        self.store.add_comment(
            issue.number,
            "The contract passed two consecutive scheduled checks and is considered recovered."
            f"\n\nLatest run: {current.run_url}",
        )
        self.store.update_issue(issue.number, state="closed")
        return f"closed {check.key}"


def report_markdown(report: ContractReport) -> str:
    lines = ["## Yostar contract monitor", "", f"Checked: `{report.checked_at}`", ""]
    lines.extend(
        ["| Region | Contract | Result | Detail |", "| --- | --- | --- | --- |"]
    )
    for check in report.checks:
        detail = check.summary.replace("|", "\\|").replace("\n", " ")
        lines.append(
            f"| {check.region.title()} | {check.contract} | {check.status} | {detail} |"
        )
    return "\n".join(lines) + "\n"


def _parse_check(value: object) -> ContractCheck:
    if not isinstance(value, dict):
        raise TypeError("contract report check must be an object")
    status = _required_string(value, "status")
    if status not in {"healthy", "failed", "blocked"}:
        raise ValueError(f"unsupported contract check status: {status}")
    region = _required_string(value, "region")
    if region not in SUPPORTED_REGIONS:
        raise ValueError(f"unsupported contract region: {region}")
    contract = _required_string(value, "contract")
    if contract not in SUPPORTED_CONTRACTS:
        raise ValueError(f"unsupported contract category: {contract}")
    summary = _required_string(value, "summary")
    if len(summary) > 240 or not SAFE_SUMMARY_PATTERN.fullmatch(summary):
        raise ValueError("contract summary must be a short single line")
    return ContractCheck(
        region=region,
        contract=contract,
        status=status,
        summary=summary,
    )


def _required_string(value: dict[object, object], key: str) -> str:
    result = value.get(key)
    if not isinstance(result, str) or not result:
        raise ValueError(f"contract report {key} must be a non-empty string")
    return result


def _has_consecutive_status(
    current: ContractCheck,
    previous: list[ContractCheck],
    status: str,
    count: int,
) -> bool:
    sequence = [current, *previous]
    return len(sequence) >= count and all(
        item.status == status for item in sequence[:count]
    )


def _consecutive_reports(
    current: ContractReport,
    previous: list[ContractReport],
    status: str,
    key: str,
) -> list[ContractReport]:
    reports = [current]
    for report in previous:
        check = report.check_by_key(key)
        if check is None or check.status != status:
            break
        reports.append(report)
    return reports


def _first_report_with_status(
    previous: list[ContractReport], status: str, key: str
) -> ContractReport | None:
    for report in previous:
        check = report.check_by_key(key)
        if check is not None and check.status == status:
            return report
    return None


def _issue_title(check: ContractCheck) -> str:
    return f"[Monitor] {check.region.title()} {check.contract} contract is failing"


def _failure_body(
    *,
    check: ContractCheck,
    first_failure: ContractReport,
    latest_failure: ContractReport,
    last_success: ContractReport | None,
) -> str:
    last_success_text = (
        last_success.checked_at if last_success else "No retained healthy report"
    )
    return "\n".join(
        [
            f"<!-- {MONITOR_MARKER_PREFIX}{check.key} -->",
            f"<!-- monitor-condition:{check.condition} -->",
            "## Automated contract alert",
            "",
            f"The **{check.region.title()}** `{check.contract}` contract failed in two consecutive scheduled checks.",
            "",
            f"- First failure: {first_failure.checked_at}",
            f"- Latest failure: {latest_failure.checked_at}",
            f"- Last known success: {last_success_text}",
            f"- Sanitized failure: `{check.summary}`",
            f"- Latest workflow run: {latest_failure.run_url}",
            "",
            "This issue is maintained automatically. Response bodies and authorization values are never included.",
        ]
    )

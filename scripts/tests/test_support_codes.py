# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import pytest
from lib.common import PROJECT_DIR, ScriptError
from lib.project_config import (
    SUPPORT_CODE_CATALOG,
)
from lib.support_codes import (
    check,
    load_catalog,
    parse_catalog,
)

RETIRED_CODES = {
    "VIRGA",
    "PEBBLE",
    "GABBRO",
    "BASALT",
    "SCREE",
    "LIMPET",
    "WHELK",
    "SEPIA",
    "ANEMONE",
    "NARWHAL",
    "CRUX",
}

ISSUE_TEMPLATE = """name: Problem report
body:
  # support-codes:begin code
  - type: dropdown
    id: code
    attributes:
      label: Error code
  # support-codes:end code
"""

INDEX_TEMPLATE = """# Error codes

<!-- support-codes:begin codes -->
<!-- support-codes:end codes -->

<!-- support-codes:begin retired -->
<!-- support-codes:end retired -->
"""


def entry(**overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "code": "IN-DLD",
        "swiftName": "downloadDamaged",
        "domain": "installation",
        "title": "Download damaged",
        "status": "active",
        "summary": "The download is damaged.",
        "action": "Retry the download.",
        "allowsRetry": True,
        "allowsRepair": False,
        "causes": ["The download stopped early."],
        "steps": ["Retry the download."],
        "report": "The download failed.",
        "legacy": [],
    }
    base.update(overrides)
    return base


def test_committed_outputs_match_the_catalog() -> None:
    assert check(PROJECT_DIR) == []


def test_catalog_covers_every_retired_code() -> None:
    catalog = load_catalog(PROJECT_DIR / SUPPORT_CODE_CATALOG)
    assert set(catalog.legacy_codes) == RETIRED_CODES


@pytest.mark.parametrize(
    ("change", "message"),
    [
        ({"code": "IN-DL"}, "XX-XXX"),
        ({"code": "in-dld"}, "XX-XXX"),
        ({"code": "SV-DLD"}, "code prefix must match its domain"),
        ({"swiftName": "Download"}, "lowerCamelCase"),
        ({"status": "retired"}, "status must be active"),
        ({"summary": 'Quoted "text".'}, "plain ASCII"),
        ({"summary": "Back\\slash"}, "plain ASCII"),
        ({"allowsRetry": "yes"}, "true or false"),
        ({"steps": []}, "non-empty list"),
        ({"legacy": ["lower"]}, "uppercase letters only"),
        ({"legacy": ["IN-DLD"]}, "uppercase letters only"),
    ],
)
def test_invalid_entries_fail(change: dict[str, object], message: str) -> None:
    with pytest.raises(ScriptError, match=message):
        parse_catalog({"codes": [entry(**change)]}, "catalog")


def test_duplicate_codes_fail() -> None:
    with pytest.raises(ScriptError, match="codes must be unique"):
        parse_catalog({"codes": [entry(), entry(swiftName="other")]}, "catalog")

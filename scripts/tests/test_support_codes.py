# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import copy
import json
import re
from pathlib import Path

import pytest
from lib.common import PROJECT_DIR, ScriptError
from lib.project_config import (
    ISSUE_REPORT_TEMPLATE,
    SUPPORT_CODE_ARTICLES,
    SUPPORT_CODE_CATALOG,
)
from lib.support_codes import (
    GENERATED_NOTE,
    check,
    load_catalog,
    parse_catalog,
    regenerate,
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


def write_root(root: Path, codes: list[dict[str, object]]) -> None:
    catalog = root / SUPPORT_CODE_CATALOG
    catalog.write_text(json.dumps({"codes": codes}), encoding="utf-8")
    template = root / ISSUE_REPORT_TEMPLATE
    template.parent.mkdir(parents=True, exist_ok=True)
    template.write_text(ISSUE_TEMPLATE, encoding="utf-8")
    index = root / SUPPORT_CODE_ARTICLES / "README.md"
    index.parent.mkdir(parents=True, exist_ok=True)
    index.write_text(INDEX_TEMPLATE, encoding="utf-8")


def test_committed_outputs_match_the_catalog() -> None:
    assert check(PROJECT_DIR) == []


def test_catalog_covers_every_retired_code() -> None:
    catalog = load_catalog(PROJECT_DIR / SUPPORT_CODE_CATALOG)
    assert set(catalog.legacy_codes) == RETIRED_CODES


def test_active_codes_use_the_domain_scheme() -> None:
    catalog = load_catalog(PROJECT_DIR / SUPPORT_CODE_CATALOG)
    codes = [item.code for item in catalog.active]
    assert len(codes) == len(set(codes))
    assert all(len(code) == 6 and code[2] == "-" for code in codes)


def test_regenerate_is_idempotent(tmp_path: Path) -> None:
    write_root(tmp_path, [entry(legacy=["OLDIN"])])
    assert regenerate(tmp_path)
    assert regenerate(tmp_path) == []
    assert check(tmp_path) == []


def test_drift_is_reported_for_stale_missing_and_orphaned_files(tmp_path: Path) -> None:
    write_root(tmp_path, [entry()])
    regenerate(tmp_path)
    page = tmp_path / "docs/help/errors/in-dld.md"
    page.write_text(page.read_text(encoding="utf-8") + "\nedited\n", encoding="utf-8")
    registry = tmp_path / "docs/help/errors/registry.json"
    registry.unlink()
    orphan = tmp_path / "docs/help/errors/zz-zzz.md"
    orphan.write_text(f"<!-- {GENERATED_NOTE} -->\n", encoding="utf-8")

    problems = "\n".join(check(tmp_path))

    assert "in-dld.md: generated file is stale" in problems
    assert "registry.json: missing" in problems
    assert "zz-zzz.md: no catalog entry" in problems


def test_single_successor_gets_a_hidden_page(tmp_path: Path) -> None:
    write_root(tmp_path, [entry(legacy=["OLDIN"])])
    regenerate(tmp_path)
    page = (tmp_path / "docs/help/errors/oldin.md").read_text(encoding="utf-8")
    assert "hidden: true" in page
    assert "Launcher 0.8.0 replaced OLDIN with **IN-DLD**." in page
    assert "[IN-DLD](in-dld.md)" in page


def test_every_legacy_code_has_a_hidden_page_naming_its_successors() -> None:
    catalog = load_catalog(PROJECT_DIR / SUPPORT_CODE_CATALOG)
    for legacy in catalog.legacy_codes:
        page = PROJECT_DIR / SUPPORT_CODE_ARTICLES / f"{legacy.lower()}.md"
        text = page.read_text(encoding="utf-8")
        assert "hidden: true" in text
        for successor in catalog.successors(legacy):
            assert f"[{successor.code}]({successor.lower}.md)" in text


def test_index_lists_every_active_and_legacy_code() -> None:
    catalog = load_catalog(PROJECT_DIR / SUPPORT_CODE_CATALOG)
    index = (PROJECT_DIR / SUPPORT_CODE_ARTICLES / "README.md").read_text(
        encoding="utf-8"
    )
    for item in catalog.active:
        assert f"[{item.code}]({item.lower}.md)" in index
    for legacy in catalog.legacy_codes:
        assert f"| {legacy} |" in index


def generated_pages() -> list[Path]:
    return [
        path
        for path in (PROJECT_DIR / SUPPORT_CODE_ARTICLES).glob("*.md")
        if GENERATED_NOTE in path.read_text(encoding="utf-8")
    ]


def test_pages_have_no_heading_above_the_front_matter_title() -> None:
    pages = generated_pages()
    assert pages
    for page in pages:
        body = page.read_text(encoding="utf-8").split("\n---\n", 1)[1]
        assert not re.search(r"^# ", body, re.MULTILINE), page.name


def test_pages_do_not_double_the_ellipsis_punctuation() -> None:
    for page in generated_pages():
        text = page.read_text(encoding="utf-8")
        assert not re.search(r"…(\*\*)?\.", text), page.name


def test_retired_code_leaves_no_page_once_removed(tmp_path: Path) -> None:
    write_root(tmp_path, [entry(legacy=["OLDIN"])])
    regenerate(tmp_path)
    write_root(tmp_path, [entry()])
    regenerate(tmp_path)
    assert not (tmp_path / "docs/help/errors/oldin.md").exists()


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


def test_unknown_keys_fail() -> None:
    bad = copy.deepcopy(entry())
    bad["extra"] = True
    with pytest.raises(ScriptError, match="keys must be exactly"):
        parse_catalog({"codes": [bad]}, "catalog")

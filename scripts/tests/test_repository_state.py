# SPDX-License-Identifier: MPL-2.0

import pytest
from lib.common import PROJECT_DIR
from lib.design_lint import check as check_design_lint
from lib.project_config import APPCAST_FEED_TAG, RUNTIME_CONFIG
from lib.sleep_lint import check as check_sleep_lint
from lib.try_lint import check as check_try_lint
from runtime_config import load_runtime_config


def test_feature_sources_have_no_design_lint_violations() -> None:
    assert check_design_lint(PROJECT_DIR) == []


def test_test_sources_have_no_real_sleeps() -> None:
    assert check_sleep_lint(PROJECT_DIR) == []


def test_runtime_sources_have_no_silent_try() -> None:
    assert check_try_lint(PROJECT_DIR) == []


@pytest.mark.parametrize("workflow", ["release", "publish-appcast", "promote", "pages"])
def test_workflows_name_the_canonical_appcast_release(workflow: str) -> None:
    text = (PROJECT_DIR / f".github/workflows/{workflow}.yml").read_text()

    assert f"\n  APPCAST_TAG: {APPCAST_FEED_TAG}\n" in text


def test_repository_runtime_pin_loads() -> None:
    load_runtime_config(PROJECT_DIR / RUNTIME_CONFIG)

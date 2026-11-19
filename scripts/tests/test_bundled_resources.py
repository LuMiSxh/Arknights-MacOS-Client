# SPDX-License-Identifier: MPL-2.0

from pathlib import Path

import build_app
import pytest
from lib import bundled_resources
from lib.bundled_resources import (
    registry_drift,
    staged_resources,
)
from lib.project_config import (
    RUNTIME_CONFIG,
    ProjectConfiguration,
    load_project_configuration,
)

REGISTRY = """
extension BundledResource {
	static let a = BundledResource(file: "LICENSE", origin: .app)
	static let b = BundledResource(
		file: "ThirdPartyNotices.deflate", origin: .app, encoding: .deflate)
	static let c = BundledResource(directory: "SupportArticles", origin: .app)
}
"""


@pytest.fixture(scope="module")
def configuration() -> ProjectConfiguration:
    return load_project_configuration()


def test_drift_reports_missing_extra_and_changed_resources(
    configuration: ProjectConfiguration,
) -> None:
    registry = bundled_resources.swift_registry_path(configuration)
    source = (configuration.project_directory / registry).read_text(encoding="utf-8")

    without_license = source.replace('file: "LICENSE"', 'file: "LICENSE.txt"')
    problems = registry_drift(configuration, without_license)
    assert any(
        "does not list" in problem and "LICENSE" in problem for problem in problems
    )
    assert any(
        "does not stage" in problem and "LICENSE.txt" in problem for problem in problems
    )

    changed_format = source.replace(
        'file: "CHANGELOG.md", origin: .app',
        'file: "CHANGELOG.md", origin: .app, encoding: .deflate',
    )
    assert registry_drift(configuration, changed_format)

    assert registry_drift(configuration, source + "\n" + REGISTRY.splitlines()[2])


def test_build_copies_every_resource_that_has_a_source(
    configuration: ProjectConfiguration,
) -> None:
    copies = dict(build_app.app_resources(configuration))

    for resource in staged_resources(configuration):
        if resource.source is not None:
            assert (
                copies[configuration.project_directory / resource.source].as_posix()
                == resource.path
            )
            assert (configuration.project_directory / resource.source).exists()


def test_stage_app_resources_replaces_stale_copies(
    configuration: ProjectConfiguration, tmp_path: Path
) -> None:
    resources = tmp_path / "Resources"
    stale = resources / "SupportArticles" / "removed.md"
    stale.parent.mkdir(parents=True)
    stale.write_text("stale", encoding="utf-8")

    bundled_resources.stage_app_resources(configuration, resources)
    bundled_resources.stage_app_resources(configuration, resources)

    project = configuration.project_directory
    assert (resources / "RUNTIME.json").read_bytes() == (
        project / RUNTIME_CONFIG
    ).read_bytes()
    assert sorted(p.name for p in (resources / "SupportArticles").iterdir()) == sorted(
        p.name for p in (project / "docs/help/errors").iterdir()
    )
    assert not stale.exists()

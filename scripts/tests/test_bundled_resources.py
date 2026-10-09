# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from dataclasses import replace

import build_app
import pytest
from lib import bundled_resources
from lib.bundled_resources import (
    DEFLATE,
    FIXED_RESOURCES,
    IDENTITY,
    registry_drift,
    staged_resources,
    swift_registry,
)
from lib.licenses import BUNDLE_NOTICES_NAME
from lib.project_config import ProjectConfiguration, load_project_configuration

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


def test_swift_registry_matches_the_staging_table(
    configuration: ProjectConfiguration,
) -> None:
    assert registry_drift(configuration) == []


def test_parser_reads_single_and_multi_line_declarations() -> None:
    assert swift_registry(REGISTRY) == (
        ("LICENSE", "file", "app", IDENTITY),
        ("ThirdPartyNotices.deflate", "file", "app", DEFLATE),
        ("SupportArticles", "directory", "app", IDENTITY),
    )


def test_drift_reports_missing_extra_and_changed_resources(
    configuration: ProjectConfiguration,
) -> None:
    source = (
        configuration.project_directory / bundled_resources.SWIFT_REGISTRY
    ).read_text(encoding="utf-8")

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


def test_icons_are_staged_but_not_read_by_name(
    configuration: ProjectConfiguration,
) -> None:
    unread = {
        resource.path
        for resource in staged_resources(configuration)
        if not resource.swift_reads
    }

    assert "Assets.car" in unread
    assert all(resource.swift_reads for resource in FIXED_RESOURCES)


def test_package_resources_come_from_package_swift(
    configuration: ProjectConfiguration,
) -> None:
    package = {
        resource.path
        for resource in staged_resources(configuration)
        if resource.origin == "package"
    }

    assert package == {
        source.name for source in configuration.copied_resource_source_paths
    }


def test_only_generated_documents_use_deflate(
    configuration: ProjectConfiguration,
) -> None:
    deflated = [
        resource
        for resource in staged_resources(configuration)
        if resource.encoding == DEFLATE
    ]

    assert [resource.path for resource in deflated] == [BUNDLE_NOTICES_NAME]
    assert deflated[0].source is None


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


def test_renamed_icon_follows_project_configuration(
    configuration: ProjectConfiguration,
) -> None:
    product = replace(configuration.product, icon_file="Other")
    renamed = replace(configuration, product=product)

    assert "Other.icns" in {resource.path for resource in staged_resources(renamed)}

# SPDX-License-Identifier: MPL-2.0

"""Read and validate the project metadata used by packaging scripts."""

from __future__ import annotations

import json
import plistlib
import re
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

from lib.common import PROJECT_DIR, fail, output, require_file

ARCHITECTURE_PATTERN = re.compile(r"^[A-Za-z0-9_]+$")
SPARKLE_DELTA_SOURCE_COUNT = 3
# Releases up to 0.6.x shipped `.zip` update archives; newer ones ship `.tar.xz`.
# Sparkle 2.9.6, the oldest shipped updater, extracts both.
SPARKLE_ARCHIVE_SUFFIXES = (".tar.xz", ".zip")
# Support-code outputs, relative to the repository root. `support-codes.json` generates them.
SUPPORT_CODE_CATALOG = Path("support-codes.json")
SUPPORT_CODE_ARTICLES = Path("docs/help/errors")
SUPPORT_CODE_SWIFT = Path("Sources/ArknightsCore/Shared/Support/SupportCode.swift")
ISSUE_REPORT_TEMPLATE = Path(".github/ISSUE_TEMPLATE/problem-report.yml")


def sparkle_archive_names(stem: str, version: str) -> set[str]:
    """Return every asset name a release's Sparkle update archive may have used."""
    return {
        name
        for suffix in SPARKLE_ARCHIVE_SUFFIXES
        for name in (f"{stem}{suffix}", f"{stem}.{version}{suffix}")
    }


def github_asset_stem(display_name: str) -> str:
    """Return the dotted filename stem GitHub uses for release assets."""
    stem = re.sub(r"[^A-Za-z0-9]+", ".", display_name).strip(".")
    if not stem:
        fail("display name must contain a GitHub-safe asset component")
    return stem


def github_asset_name(filename: str) -> str:
    """Return the filename GitHub stores when a release asset is uploaded."""
    return re.sub(r"[^A-Za-z0-9._-]+", ".", filename)


@dataclass(frozen=True)
class ProductMetadata:
    """Product properties declared by the app's Info.plist."""

    display_name: str
    bundle_name: str
    executable_name: str
    bundle_identifier: str
    marketing_version: str
    icon_name: str
    icon_file: str
    minimum_macos_version: str
    architecture_priority: tuple[str, ...]


@dataclass(frozen=True)
class PackageMetadata:
    """Build properties resolved by SwiftPM's package manifest evaluation."""

    name: str
    macos_version: str
    executable_product_name: str
    resource_target_path: Path
    copy_resource_paths: tuple[Path, ...]
    exact_dependency_versions: tuple[tuple[str, str], ...]

    def exact_dependency_version(self, identity: str) -> str:
        versions = dict(self.exact_dependency_versions)
        if identity not in versions:
            fail(f"package dependency {identity} must use an exact version")
        return versions[identity]


@dataclass(frozen=True)
class ProjectConfiguration:
    """Validated metadata and paths derived from both project declarations."""

    project_directory: Path
    product: ProductMetadata
    package: PackageMetadata

    @property
    def app_bundle_name(self) -> str:
        return f"{self.product.display_name}.app"

    @property
    def release_asset_stem(self) -> str:
        return github_asset_stem(self.product.display_name)

    @property
    def dmg_name(self) -> str:
        return f"{self.release_asset_stem}.dmg"

    @property
    def sparkle_update_name(self) -> str:
        return f"{self.release_asset_stem}.tar.xz"

    @property
    def copied_resource_source_paths(self) -> tuple[Path, ...]:
        return tuple(
            self.resource_target_directory / path
            for path in self.package.copy_resource_paths
        )

    @property
    def resource_target_directory(self) -> Path:
        return self.project_directory / self.package.resource_target_path


def load_project_configuration(
    project_dir: Path = PROJECT_DIR,
    package_dump: Mapping[str, Any] | str | bytes | None = None,
) -> ProjectConfiguration:
    """Load project metadata, evaluating Package.swift through SwiftPM when needed."""
    project_dir = project_dir.resolve()
    plist = _read_plist(project_dir / "Resources/Info.plist")
    dump = _read_package_dump(project_dir, package_dump)
    product = _product_metadata(plist)
    package = _package_metadata(dump)
    _validate_agreement(product, package, project_dir)
    return ProjectConfiguration(project_dir, product, package)


def _read_plist(path: Path) -> Mapping[str, Any]:
    require_file(path)
    try:
        with path.open("rb") as file:
            value = plistlib.load(file)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"could not read Info.plist: {error}")
    if not isinstance(value, Mapping):
        fail("Info.plist must contain a dictionary")
    return value


def _read_package_dump(
    project_dir: Path, package_dump: Mapping[str, Any] | str | bytes | None
) -> Mapping[str, Any]:
    raw = (
        output(["swift", "package", "dump-package"], cwd=project_dir)
        if package_dump is None
        else package_dump
    )
    if isinstance(raw, Mapping):
        return raw
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as error:
        fail(f"could not parse swift package dump-package output: {error}")
    if not isinstance(value, Mapping):
        fail("swift package dump-package output must contain a dictionary")
    return value


def _product_metadata(plist: Mapping[str, Any]) -> ProductMetadata:
    return ProductMetadata(
        display_name=_safe_component(
            _string(plist, "CFBundleDisplayName"), "CFBundleDisplayName"
        ),
        bundle_name=_safe_component(_string(plist, "CFBundleName"), "CFBundleName"),
        executable_name=_safe_component(
            _string(plist, "CFBundleExecutable"), "CFBundleExecutable"
        ),
        bundle_identifier=_string(plist, "CFBundleIdentifier"),
        marketing_version=_string(plist, "CFBundleShortVersionString"),
        icon_name=_safe_component(
            _string(plist, "CFBundleIconName"), "CFBundleIconName"
        ),
        icon_file=_safe_component(
            _string(plist, "CFBundleIconFile"), "CFBundleIconFile"
        ),
        minimum_macos_version=_string(plist, "LSMinimumSystemVersion"),
        architecture_priority=tuple(
            _architecture(value)
            for value in _unique_strings(plist, "LSArchitecturePriority")
        ),
    )


def _package_metadata(dump: Mapping[str, Any]) -> PackageMetadata:
    targets = _objects(dump, "targets")
    products = _objects(dump, "products")
    executable_products = [
        item for item in products if "executable" in _object(item, "type")
    ]
    if len(executable_products) != 1:
        fail("package must declare exactly one executable product")
    executable_product = executable_products[0]
    product_name = _safe_component(
        _string(executable_product, "name"), "executable product name"
    )
    resource_target = _resource_target(targets)
    return PackageMetadata(
        name=_safe_component(_string(dump, "name"), "package name"),
        macos_version=_macos_version(dump),
        executable_product_name=product_name,
        resource_target_path=_safe_relative_path(
            _string(resource_target, "path"), "resource target path"
        ),
        copy_resource_paths=_copied_resources(resource_target),
        exact_dependency_versions=_exact_dependency_versions(dump),
    )


def _resource_target(targets: list[Mapping[str, Any]]) -> Mapping[str, Any]:
    """Return the single non-test target that declares resources."""
    owners = [
        item for item in targets if item.get("type") != "test" and item.get("resources")
    ]
    if len(owners) != 1:
        fail("package must declare resources on exactly one non-test target")
    return owners[0]


def _exact_dependency_versions(
    dump: Mapping[str, Any],
) -> tuple[tuple[str, str], ...]:
    """Read `.exact` source-control requirements; SwiftPM guarantees the structure."""
    return tuple(
        (source["identity"], source["requirement"]["exact"][0])
        for dependency in _objects(dump, "dependencies")
        for source in dependency.get("sourceControl", [])
        if "exact" in source["requirement"]
    )


def _validate_agreement(
    product: ProductMetadata, package: PackageMetadata, project_directory: Path
) -> None:
    if product.display_name != product.bundle_name:
        fail("CFBundleDisplayName and CFBundleName must agree")
    if product.executable_name != package.executable_product_name:
        fail("CFBundleExecutable must match the executable product name")
    if product.icon_name != product.icon_file:
        fail("CFBundleIconName and CFBundleIconFile must agree")
    if package.macos_version != product.minimum_macos_version:
        fail("package macOS platform must match LSMinimumSystemVersion")


def _copied_resources(target: Mapping[str, Any]) -> tuple[Path, ...]:
    return tuple(
        _safe_relative_path(_string(resource, "path"), "resource path")
        for resource in _objects(target, "resources")
        if "copy" in _object(resource, "rule")
    )


def _macos_version(dump: Mapping[str, Any]) -> str:
    versions = [
        _string(platform, "version")
        for platform in _objects(dump, "platforms")
        if platform.get("platformName") == "macos"
    ]
    if len(versions) != 1:
        fail("package must declare exactly one macOS platform")
    return versions[0]


def _string(value: Mapping[str, Any], key: str) -> str:
    item = value.get(key)
    if not isinstance(item, str) or not item:
        fail(f"{key} must be a nonempty string")
    return item


def _strings(value: Mapping[str, Any], key: str) -> list[str]:
    item = value.get(key)
    if not isinstance(item, list) or not all(
        isinstance(entry, str) and entry for entry in item
    ):
        fail(f"{key} must be a list of nonempty strings")
    return item


def _unique_strings(value: Mapping[str, Any], key: str) -> list[str]:
    items = _strings(value, key)
    if len(items) != len(set(items)):
        fail(f"{key} must not contain duplicates")
    return items


def _objects(value: Mapping[str, Any], key: str) -> list[Mapping[str, Any]]:
    item = value.get(key)
    if not isinstance(item, list) or not all(
        isinstance(entry, Mapping) for entry in item
    ):
        fail(f"{key} must be a list of dictionaries")
    return item


def _object(value: Mapping[str, Any], key: str) -> Mapping[str, Any]:
    item = value.get(key)
    if not isinstance(item, Mapping):
        fail(f"{key} must be a dictionary")
    return item


def _safe_component(value: str, name: str) -> str:
    if value in {".", ".."} or "/" in value or "\\" in value or "\0" in value:
        fail(f"{name} must be a safe path component")
    return value


def _safe_relative_path(value: str, name: str) -> Path:
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or not path.parts
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        fail(f"{name} must be a safe relative path")
    return Path(*path.parts)


def _architecture(value: str) -> str:
    if ARCHITECTURE_PATTERN.fullmatch(value) is None:
        fail("LSArchitecturePriority must contain Swift architecture names")
    return value

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
    development_region: str
    localizations: tuple[str, ...]
    minimum_macos_version: str
    architecture_priority: tuple[str, ...]


@dataclass(frozen=True)
class PackageMetadata:
    """Build properties resolved by SwiftPM's package manifest evaluation."""

    name: str
    default_localization: str
    macos_version: str
    executable_product_name: str
    executable_target_name: str
    target_path: Path
    excluded_paths: tuple[Path, ...]
    copy_resource_paths: tuple[Path, ...]
    processed_resource_paths: tuple[Path, ...]


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
    def dmg_name(self) -> str:
        return f"{self.product.display_name}.dmg"

    @property
    def target_directory(self) -> Path:
        return self.project_directory / self.package.target_path

    @property
    def resource_directory(self) -> Path:
        localization_parents = {
            path.parent
            for path in self.package.processed_resource_paths
            if path.suffix == ".xcstrings"
        }
        if len(localization_parents) != 1:
            fail("package String Catalogs must share one resource directory")
        return self.target_directory / localization_parents.pop()

    @property
    def swift_resource_bundle_name(self) -> str:
        return f"{self.package.name}_{self.package.executable_target_name}.bundle"

    @property
    def copied_resource_source_paths(self) -> tuple[Path, ...]:
        return tuple(
            self.target_directory / path for path in self.package.copy_resource_paths
        )


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
    _validate_agreement(product, package)
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
    localizations = _unique_strings(plist, "CFBundleLocalizations")
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
        development_region=_language(
            _string(plist, "CFBundleDevelopmentRegion"), "CFBundleDevelopmentRegion"
        ),
        localizations=tuple(
            _language(value, "CFBundleLocalizations") for value in localizations
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
    product_targets = _strings(executable_product, "targets")
    if len(product_targets) != 1:
        fail("executable product must reference exactly one target")
    target_name = _safe_component(product_targets[0], "executable target name")
    matching = [
        item
        for item in targets
        if item.get("name") == target_name and item.get("type") == "executable"
    ]
    if len(matching) != 1:
        fail(
            f"package must declare exactly one executable target named {target_name!r}"
        )
    target = matching[0]
    copy_resources, processed_resources = _resources(target)
    return PackageMetadata(
        name=_safe_component(_string(dump, "name"), "package name"),
        default_localization=_language(
            _string(dump, "defaultLocalization"), "defaultLocalization"
        ),
        macos_version=_macos_version(dump),
        executable_product_name=product_name,
        executable_target_name=target_name,
        target_path=_safe_relative_path(_string(target, "path"), "target path"),
        excluded_paths=tuple(
            _safe_relative_path(value, "excluded path")
            for value in _optional_strings(target, "exclude")
        ),
        copy_resource_paths=copy_resources,
        processed_resource_paths=processed_resources,
    )


def _validate_agreement(product: ProductMetadata, package: PackageMetadata) -> None:
    if product.display_name != product.bundle_name:
        fail("CFBundleDisplayName and CFBundleName must agree")
    if product.executable_name != package.executable_product_name:
        fail("CFBundleExecutable must match the executable product name")
    if product.icon_name != product.icon_file:
        fail("CFBundleIconName and CFBundleIconFile must agree")
    if product.development_region not in product.localizations:
        fail("CFBundleDevelopmentRegion must be included in CFBundleLocalizations")
    if package.default_localization != product.development_region:
        fail("package defaultLocalization must match CFBundleDevelopmentRegion")
    if package.macos_version != product.minimum_macos_version:
        fail("package macOS platform must match LSMinimumSystemVersion")
    processed_catalogs = tuple(
        path for path in package.processed_resource_paths if path.suffix == ".xcstrings"
    )
    if not processed_catalogs:
        fail("package must process at least one String Catalog")
    if len(processed_catalogs) != len(set(processed_catalogs)):
        fail("package processed String Catalogs must be unique")
    if any(path.name.endswith(".lproj") for path in package.processed_resource_paths):
        fail(
            "package must process String Catalogs instead of generated .lproj resources"
        )


def _resources(target: Mapping[str, Any]) -> tuple[tuple[Path, ...], tuple[Path, ...]]:
    copied: list[Path] = []
    processed: list[Path] = []
    for resource in _objects(target, "resources"):
        path = _safe_relative_path(_string(resource, "path"), "resource path")
        rule = _object(resource, "rule")
        if "copy" in rule:
            copied.append(path)
        elif "process" in rule:
            processed.append(path)
    return tuple(copied), tuple(processed)


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


def _optional_strings(value: Mapping[str, Any], key: str) -> list[str]:
    return [] if key not in value else _strings(value, key)


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


def _language(value: str, name: str) -> str:
    return _safe_component(value, name)


def _architecture(value: str) -> str:
    if ARCHITECTURE_PATTERN.fullmatch(value) is None:
        fail("LSArchitecturePriority must contain Swift architecture names")
    return value

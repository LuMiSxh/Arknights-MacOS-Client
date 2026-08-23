#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Generate or verify SwiftPM localization resources from the String Catalog."""

from __future__ import annotations

import argparse
import json
import re
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from lib.common import PROJECT_DIR, ScriptError, run, run_main, success
from lib.project_config import ProjectConfiguration, load_project_configuration

LICENSE_HEADER = "// SPDX-License-Identifier: MPL-2.0\n\n"
KEY_PATTERN = re.compile(r"^[a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+$")
SWIFT_PACKAGE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = Foundation.Bundle.module"
)
APP_RESOURCE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = AppResourceBundle.bundle"
)


@dataclass(frozen=True)
class LocalizationLayout:
    resource_directory: Path
    generated_directory: Path
    source_language: str
    localizations: tuple[str, ...]
    catalogs: tuple[Path, ...]


@dataclass(frozen=True)
class CatalogGeneration:
    name: str
    symbols: Path
    compiled: dict[str, Path]


def discover_layout(configuration: ProjectConfiguration) -> LocalizationLayout:
    resource_directory = configuration.resource_directory
    catalogs = tuple(sorted(resource_directory.glob("*.xcstrings")))
    if not catalogs:
        raise ScriptError("no localization catalogs found")
    target_directory = configuration.target_directory
    excluded = set(configuration.package.excluded_paths)
    for catalog in catalogs:
        relative = catalog.relative_to(target_directory)
        if relative not in excluded:
            raise ScriptError(
                f"Package.swift does not exclude String Catalog: {relative}"
            )
    return LocalizationLayout(
        resource_directory=resource_directory,
        generated_directory=target_directory / "Shared/Localization",
        source_language=configuration.product.development_region,
        localizations=configuration.product.localizations,
        catalogs=catalogs,
    )


def validate_catalog(catalog_path: Path, layout: LocalizationLayout) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("sourceLanguage") != layout.source_language:
        raise ScriptError(
            "catalog source language must match CFBundleDevelopmentRegion: "
            f"{catalog_path.name}"
        )
    strings = catalog.get("strings")
    if not isinstance(strings, dict) or not strings:
        raise ScriptError("localization catalog does not contain any strings")

    for key, entry in strings.items():
        if KEY_PATTERN.fullmatch(key) is None:
            raise ScriptError(f"localization key is not feature-namespaced: {key}")
        if not isinstance(entry, dict) or not entry.get("comment", "").strip():
            raise ScriptError(
                f"localization key is missing a translator comment: {key}"
            )
        localizations = entry.get("localizations", {})
        for language in layout.localizations:
            localization = localizations.get(language)
            if not isinstance(localization, dict):
                raise ScriptError(
                    f"localization key {key} is missing language: {language}"
                )
            string_units = _string_units(localization)
            if not string_units:
                raise ScriptError(
                    f"localization key {key} has no string value for language: {language}"
                )
            for unit in string_units:
                if (
                    unit.get("state") != "translated"
                    or not unit.get("value", "").strip()
                ):
                    raise ScriptError(
                        f"localization key {key} has an incomplete {language} translation"
                    )


def _string_units(value: object) -> list[dict[str, str]]:
    if isinstance(value, dict):
        units: list[dict[str, str]] = []
        string_unit = value.get("stringUnit")
        if isinstance(string_unit, dict):
            units.append(string_unit)
        for nested in value.values():
            units.extend(_string_units(nested))
        return units
    if isinstance(value, list):
        return [unit for nested in value for unit in _string_units(nested)]
    return []


def synchronize_file(source: Path, destination: Path, *, write: bool) -> None:
    expected = source.read_bytes()
    actual = destination.read_bytes() if destination.is_file() else None
    if actual == expected:
        return
    if not write:
        raise ScriptError(
            f"generated localization file is stale: {_display_path(destination)}"
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(expected)


def remove_stale_files(
    actual_files: set[Path], expected_files: set[Path], *, write: bool
) -> None:
    for stale in sorted(actual_files - expected_files):
        if not write:
            raise ScriptError(
                f"obsolete generated localization file remains: {_display_path(stale)}"
            )
        stale.unlink()


def _display_path(path: Path) -> Path:
    try:
        return path.relative_to(PROJECT_DIR)
    except ValueError:
        return path


def use_app_resource_bundle(generated_symbols: str) -> str:
    if generated_symbols.count(SWIFT_PACKAGE_BUNDLE_DECLARATION) != 1:
        raise ScriptError("unexpected generated Swift package resource declaration")
    return generated_symbols.replace(
        SWIFT_PACKAGE_BUNDLE_DECLARATION,
        APP_RESOURCE_BUNDLE_DECLARATION,
    )


def generate_catalog(
    layout: LocalizationLayout,
    catalog: Path,
    output_directory: Path,
) -> CatalogGeneration:
    catalog_directory = output_directory / catalog.stem
    compiled_directory = catalog_directory / "compiled"
    symbols_directory = catalog_directory / "symbols"
    symbols_directory.mkdir(parents=True)
    run(
        [
            "xcrun",
            "xcstringstool",
            "compile",
            catalog,
            "--output-directory",
            compiled_directory,
            "--format",
            "stringsAndStringsdict",
        ],
        cwd=PROJECT_DIR,
    )
    run(
        [
            "xcrun",
            "xcstringstool",
            "generate-symbols",
            catalog,
            "--output-directory",
            symbols_directory,
            "--language",
            "swift",
        ],
        cwd=PROJECT_DIR,
    )
    generated_symbols = tuple(symbols_directory.glob("*.swift"))
    if len(generated_symbols) != 1:
        raise ScriptError(f"unexpected generated symbol output for {catalog.name}")
    symbols_path = generated_symbols[0]
    symbols = use_app_resource_bundle(symbols_path.read_text(encoding="utf-8"))
    symbols_path.write_text(LICENSE_HEADER + symbols, encoding="utf-8")
    return CatalogGeneration(
        name=catalog.stem,
        symbols=symbols_path,
        compiled={
            language: compiled_directory / f"{language}.lproj/{catalog.stem}.strings"
            for language in layout.localizations
        },
    )


def generate_localization(
    layout: LocalizationLayout, output_directory: Path
) -> tuple[dict[str, Path], dict[tuple[str, str], Path]]:
    with ThreadPoolExecutor(max_workers=min(4, len(layout.catalogs))) as executor:
        generations = tuple(
            executor.map(
                lambda catalog: generate_catalog(layout, catalog, output_directory),
                layout.catalogs,
            )
        )
    generated = {generation.name: generation.symbols for generation in generations}
    run(
        [
            "swift",
            "format",
            "format",
            "--configuration",
            PROJECT_DIR / ".swift-format",
            "--in-place",
            *generated.values(),
        ],
        cwd=PROJECT_DIR,
    )
    compiled = {
        (generation.name, language): path
        for generation in generations
        for language, path in generation.compiled.items()
    }
    return generated, compiled


def synchronize_localization(
    *,
    write: bool,
    configuration: ProjectConfiguration | None = None,
) -> None:
    configuration = configuration or load_project_configuration()
    layout = discover_layout(configuration)
    for catalog in layout.catalogs:
        validate_catalog(catalog, layout)
    with tempfile.TemporaryDirectory() as directory:
        generated, compiled = generate_localization(layout, Path(directory))
        expected_symbols = {
            layout.generated_directory / f"GeneratedStringSymbols_{catalog_name}.swift"
            for catalog_name in generated
        }
        for catalog_name, source in generated.items():
            destination = (
                layout.generated_directory
                / f"GeneratedStringSymbols_{catalog_name}.swift"
            )
            synchronize_file(source, destination, write=write)
        remove_stale_files(
            set(layout.generated_directory.glob("GeneratedStringSymbols_*.swift")),
            expected_symbols,
            write=write,
        )
        for (catalog_name, language), source in compiled.items():
            destination = (
                layout.resource_directory / f"{language}.lproj/{catalog_name}.strings"
            )
            synchronize_file(source, destination, write=write)
        for language in layout.localizations:
            expected_strings = {
                layout.resource_directory / f"{language}.lproj/{catalog_name}.strings"
                for catalog_name in generated
            }
            remove_stale_files(
                set(
                    (layout.resource_directory / f"{language}.lproj").glob("*.strings")
                ),
                expected_strings,
                write=write,
            )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "format"))
    arguments = parser.parse_args()
    synchronize_localization(write=arguments.mode == "format")
    success(f"localization {arguments.mode} complete")


if __name__ == "__main__":
    run_main(main)

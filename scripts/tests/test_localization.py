# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import localization
import pytest
from lib.common import ScriptError
from lib.project_config import load_project_configuration


def layout(
    root: Path,
    *,
    localizations: tuple[str, ...] = ("en", "de"),
    catalogs: tuple[Path, ...] = (),
) -> localization.LocalizationLayout:
    return localization.LocalizationLayout(
        resource_directory=root,
        generated_directory=root / "Generated",
        source_language="en",
        localizations=localizations,
        catalogs=catalogs,
    )


def test_generated_symbols_use_the_packaged_app_resource_bundle() -> None:
    generated = (
        "#if SWIFT_PACKAGE\n"
        "private nonisolated let resourceBundle = Foundation.Bundle.module\n"
        "#endif\n"
    )

    result = localization.use_app_resource_bundle(generated)

    assert "AppResourceBundle.bundle" in result
    assert "Foundation.Bundle.module" not in result


def test_rejects_catalog_keys_without_shipping_translations(tmp_path: Path) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    catalog.write_text(
        json.dumps(
            {
                "sourceLanguage": "en",
                "strings": {
                    "home.settings": {
                        "comment": "Settings button",
                        "localizations": {
                            "en": {
                                "stringUnit": {
                                    "state": "translated",
                                    "value": "Settings",
                                }
                            }
                        },
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ScriptError, match="missing language: de"):
        localization.validate_catalog(catalog, layout(catalog.parent))


def test_shipping_languages_come_from_the_layout(tmp_path: Path) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    localizations = {
        language: {"stringUnit": {"state": "translated", "value": language}}
        for language in ("en", "de", "fr")
    }
    catalog.write_text(
        json.dumps(
            {
                "sourceLanguage": "en",
                "strings": {
                    "home.settings": {
                        "comment": "Settings button",
                        "localizations": localizations,
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    localization.validate_catalog(
        catalog,
        layout(catalog.parent, localizations=("en", "de", "fr")),
    )


def test_catalog_fingerprint_invalidates_symbols_after_copy_changes(
    tmp_path: Path,
) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    symbols = tmp_path / "GeneratedStringSymbols_Localizable.swift"
    catalog.write_text("first", encoding="utf-8")
    fingerprint = localization.catalog_fingerprint(catalog)
    symbols.write_text(
        f"{localization.LICENSE_HEADER}"
        f"{localization.APP_RESOURCE_BUNDLE_DECLARATION}\n"
        f"{localization.FINGERPRINT_PREFIX}{fingerprint}\n",
        encoding="utf-8",
    )

    assert localization.symbols_are_current(symbols, fingerprint)

    catalog.write_text("second", encoding="utf-8")
    assert not localization.symbols_are_current(
        symbols, localization.catalog_fingerprint(catalog)
    )


def test_compiles_swift_resource_bundle_catalogs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    configuration = load_project_configuration()
    binary_directory = tmp_path / "bin"
    bundle = binary_directory / configuration.swift_resource_bundle_name
    bundle.mkdir(parents=True)
    catalogs = (bundle / "Launcher.xcstrings", bundle / "Settings.xcstrings")
    for catalog in catalogs:
        catalog.write_text("{}", encoding="utf-8")

    commands: list[list[str | Path]] = []

    def fake_run(command: list[str | Path], *, cwd: Path) -> None:
        commands.append(command)
        catalog = Path(command[3])
        for language in configuration.product.localizations:
            output = bundle / f"{language}.lproj" / f"{catalog.stem}.strings"
            output.parent.mkdir(exist_ok=True)
            output.touch()

    monkeypatch.setattr(localization, "run", fake_run)

    localization.compile_swift_localizations(binary_directory, configuration)

    assert len(commands) == len(catalogs)
    for command, catalog in zip(commands, catalogs, strict=True):
        assert command[:4] == [
            "xcrun",
            "xcstringstool",
            "compile",
            catalog,
        ]
        assert command[command.index("--output-directory") + 1] == bundle
        assert all(
            language in command for language in configuration.product.localizations
        )

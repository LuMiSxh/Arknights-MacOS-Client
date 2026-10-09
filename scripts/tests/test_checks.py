# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path

import build_compatibility
import checks
from lib.common import PROJECT_DIR


def test_compatibility_manifest_declares_native_sources_once() -> None:
    components = build_compatibility.load_components()
    artifacts = [
        (
            PROJECT_DIR
            / "RuntimeSupport"
            / component["directory"]
            / artifact["source"],
            (component["directory"], artifact["output"]),
        )
        for component in components
        for artifact in component["artifacts"]
    ]
    sources, outputs = zip(*artifacts, strict=True)

    assert sorted(sources) == sorted(
        path
        for suffix in ("*.c", "*.m")
        for path in (PROJECT_DIR / "RuntimeSupport").rglob(suffix)
    )
    assert len(outputs) == len(set(outputs))


def write_swift(root: Path, relative: str, source: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")


def test_layering_check_flags_lower_layers_naming_feature_types(tmp_path: Path) -> None:
    write_swift(tmp_path, "Features/Game/Thing.swift", "struct FeatureThing {}\n")
    write_swift(tmp_path, "Shared/Domain/Shared.swift", "struct SharedThing {}\n")
    write_swift(
        tmp_path,
        "Infrastructure/Net/Client.swift",
        "// FeatureThing in a comment is fine\nlet value = FeatureThing()\n",
    )
    write_swift(tmp_path, "Shared/Domain/Clean.swift", "let value = SharedThing()\n")

    assert checks.layering_violations(tmp_path) == [
        "Infrastructure/Net/Client.swift:2: FeatureThing"
    ]


def test_layering_check_ignores_names_also_declared_in_lower_layers(
    tmp_path: Path,
) -> None:
    write_swift(tmp_path, "Features/A/State.swift", "enum State {}\n")
    write_swift(tmp_path, "Shared/State.swift", "enum State {}\nlet x: State\n")

    assert checks.layering_violations(tmp_path) == []


def test_project_sources_respect_layering() -> None:
    assert checks.layering_violations() == []

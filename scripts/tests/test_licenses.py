# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from dataclasses import replace
from pathlib import Path

import pytest
from conftest import runtime_manifest
from lib import licenses
from lib.common import PROJECT_DIR, ScriptError
from lib.project_config import ProjectConfiguration, load_project_configuration


def component(**overrides: object) -> dict[str, object]:
    entry: dict[str, object] = {
        "name": "Example",
        "version": "1.0.0",
        "spdx": "MIT",
        "source": "https://example.com/example",
        "files": ["example.txt"],
        "status": "verified",
        "basis": "license-file-in-source",
    }
    entry.update(overrides)
    return entry


@pytest.fixture(scope="module")
def base_configuration() -> ProjectConfiguration:
    return load_project_configuration()


@pytest.fixture(autouse=True)
def route_configuration(
    monkeypatch: pytest.MonkeyPatch, base_configuration: ProjectConfiguration
) -> None:
    """Load the repository's package metadata for each test tree."""
    monkeypatch.setattr(
        licenses,
        "load_project_configuration",
        lambda root: replace(base_configuration, project_directory=root),
    )


@pytest.fixture
def project(tmp_path: Path) -> Path:
    """A minimal project tree that passes every check."""
    root = tmp_path
    (root / "docs/legal/licenses").mkdir(parents=True)
    (root / "docs/legal/licenses/example.txt").write_text("MIT text", encoding="utf-8")
    (root / "Sources/ArknightsCore/Resources").mkdir(parents=True)
    (root / "Sources/ArknightsCore/Resources/Art.png").touch()
    (root / "web").mkdir()
    (root / "web/package.json").write_text(
        json.dumps({"dependencies": {"lib": "1.2.3"}, "devDependencies": {}}),
        encoding="utf-8",
    )
    (root / "Package.resolved").write_text(
        json.dumps({"pins": [{"identity": "pkg", "state": {"version": "2.0.0"}}]}),
        encoding="utf-8",
    )
    (root / "runtime.json").write_text(json.dumps(runtime_manifest()), encoding="utf-8")
    write_index(
        root,
        [
            component(name="pkg", version="2.0.0", ecosystem="swiftpm", package="pkg"),
            component(
                name="lib",
                version="1.2.3",
                ecosystem="npm",
                package="lib",
                scope="website",
                files=["example.txt"],
            ),
            component(
                name="Art",
                files=[],
                paths=["Art.png"],
                status="unverified",
                basis=None,
                spdx="NOASSERTION",
            ),
        ],
    )
    for name in ("third-party-notices.md", "source-code.md", "license-texts.md"):
        blocks = {
            "third-party-notices.md": ("launcher", "website", "runtime"),
            "source-code.md": ("offer",),
            "license-texts.md": ("texts", "runtime-texts"),
        }[name]
        body = "".join(
            f"<!-- licenses:begin {block} -->\n<!-- licenses:end {block} -->\n"
            for block in blocks
        )
        (root / "docs/legal" / name).write_text(f"# Doc\n\n{body}", encoding="utf-8")
    regenerate(root)
    return root


def regenerate(root: Path, runtime: Path | None = None) -> None:
    licenses.regenerate(root)


def write_index(root: Path, components: list[dict[str, object]]) -> None:
    (root / licenses.CLIENT_INDEX).write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "textOrigins": {"example.txt": "test"},
                "components": components,
            }
        ),
        encoding="utf-8",
    )


def test_project_inventory_is_current() -> None:
    licenses.check_all(PROJECT_DIR)


def test_new_website_dependency_and_resource_fail(project: Path) -> None:
    (project / "web/package.json").write_text(
        json.dumps({"dependencies": {"lib": "1.2.3", "other": "1.0.0"}}),
        encoding="utf-8",
    )
    (project / "Sources/ArknightsCore/Resources/New.svg").touch()
    with pytest.raises(ScriptError) as error:
        licenses.check_all(project)
    assert "other has no index entry" in str(error.value)
    assert "New.svg: bundled resource has no index entry" in str(error.value)


def make_runtime(root: Path, status: str = "verified") -> Path:
    runtime = root / "runtime"
    (runtime / "Licenses/runtime").mkdir(parents=True)
    (runtime / "Licenses/runtime/MIT.txt").write_text("MIT", encoding="utf-8")
    entry = component(name="Lib", files=["runtime/MIT.txt"], status=status, spdx="MIT")
    if status == "unverified":
        entry.pop("basis")
    (runtime / "Licenses/index.json").write_text(
        json.dumps({"schemaVersion": 1, "components": [entry]}), encoding="utf-8"
    )
    (runtime / "NOTICE.md").write_text("Runtime notice", encoding="utf-8")
    return runtime


def test_runtime_index_http_sources_load_as_https(tmp_path: Path) -> None:
    runtime = make_runtime(tmp_path)
    index = runtime / "Licenses/index.json"
    document = json.loads(index.read_text(encoding="utf-8"))
    document["components"][0]["source"] = "http://example.org/lib"
    index.write_text(json.dumps(document), encoding="utf-8")
    problems: list[str] = []

    legal = licenses.load_runtime_legal(runtime, problems)

    assert problems == []
    assert legal is not None
    assert legal.components[0].source == "https://example.org/lib"

# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest
from lib import licenses
from lib.common import PROJECT_DIR, ScriptError


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


@pytest.fixture
def project(tmp_path: Path) -> Path:
    """A minimal project tree that passes every check."""
    root = tmp_path
    (root / "docs/legal/licenses").mkdir(parents=True)
    (root / "docs/legal/licenses/example.txt").write_text("MIT text", encoding="utf-8")
    (root / "Sources/ArknightsClient/Resources").mkdir(parents=True)
    (root / "Sources/ArknightsClient/Resources/Art.png").touch()
    (root / "web").mkdir()
    (root / "web/package.json").write_text(
        json.dumps({"dependencies": {"lib": "1.2.3"}, "devDependencies": {}}),
        encoding="utf-8",
    )
    (root / "Package.resolved").write_text(
        json.dumps({"pins": [{"identity": "pkg", "state": {"version": "2.0.0"}}]}),
        encoding="utf-8",
    )
    (root / "runtime.json").write_text(
        (PROJECT_DIR / "runtime.json").read_text(encoding="utf-8"), encoding="utf-8"
    )
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
            "license-texts.md": ("texts",),
        }[name]
        body = "".join(
            f"<!-- licenses:begin {block} -->\n<!-- licenses:end {block} -->\n"
            for block in blocks
        )
        (root / "docs/legal" / name).write_text(f"# Doc\n\n{body}", encoding="utf-8")
    regenerate(root)
    return root


def regenerate(root: Path, runtime: Path | None = None) -> None:
    for path, text in licenses.generate_documents(root, runtime).items():
        (root / path).write_text(text, encoding="utf-8")
    licenses.write_compiled_notices(root, runtime)


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


def rewrite(root: Path, mutate: object) -> None:
    path = root / licenses.CLIENT_INDEX
    document = json.loads(path.read_text(encoding="utf-8"))
    mutate(document)  # type: ignore[operator]
    path.write_text(json.dumps(document), encoding="utf-8")


def test_project_inventory_is_current() -> None:
    licenses.check_all(PROJECT_DIR)


def test_minimal_project_passes_and_warns_about_unverified(project: Path) -> None:
    assert licenses.check_all(project) == ["Art 1.0.0: license not yet verified"]


def test_strict_mode_fails_on_unverified(project: Path) -> None:
    with pytest.raises(ScriptError, match="license not yet verified"):
        licenses.check_all(project, strict=True)


def test_new_swiftpm_pin_without_entry_fails(project: Path) -> None:
    (project / "Package.resolved").write_text(
        json.dumps(
            {
                "pins": [
                    {"identity": "pkg", "state": {"version": "2.0.0"}},
                    {"identity": "newpkg", "state": {"version": "1.0.0"}},
                ]
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(ScriptError, match="newpkg 1.0.0 has no index entry"):
        licenses.check_all(project)


def test_updated_swiftpm_pin_fails_until_index_follows(project: Path) -> None:
    (project / "Package.resolved").write_text(
        json.dumps({"pins": [{"identity": "pkg", "state": {"version": "2.1.0"}}]}),
        encoding="utf-8",
    )
    with pytest.raises(ScriptError, match="pkg is 2.1.0, the index says 2.0.0"):
        licenses.check_all(project)


def test_new_website_dependency_and_resource_fail(project: Path) -> None:
    (project / "web/package.json").write_text(
        json.dumps({"dependencies": {"lib": "1.2.3", "other": "1.0.0"}}),
        encoding="utf-8",
    )
    (project / "Sources/ArknightsClient/Resources/New.svg").touch()
    with pytest.raises(ScriptError) as error:
        licenses.check_all(project)
    assert "other has no index entry" in str(error.value)
    assert "New.svg: bundled resource has no index entry" in str(error.value)


def test_orphan_text_and_missing_origin_fail(project: Path) -> None:
    (project / "docs/legal/licenses/orphan.txt").write_text("x", encoding="utf-8")
    with pytest.raises(
        ScriptError, match="orphan.txt: license text has no index entry"
    ):
        licenses.check_all(project)


def test_verified_entry_needs_basis_and_safe_paths(project: Path) -> None:
    def mutate(document: dict[str, object]) -> None:
        entries = document["components"]
        assert isinstance(entries, list)
        entries[0].pop("basis")
        entries[0]["files"] = ["../escape.txt"]

    rewrite(project, mutate)
    with pytest.raises(ScriptError) as error:
        licenses.check_all(project)
    assert "needs a basis" in str(error.value)
    assert "unsafe files path" in str(error.value)


def test_stale_generated_block_fails_and_generate_repairs_it(project: Path) -> None:
    notices = project / licenses.NOTICES_DOCUMENT
    notices.write_text(
        notices.read_text(encoding="utf-8").replace(
            "<!-- licenses:begin launcher -->\n",
            "<!-- licenses:begin launcher -->\nold\n",
        ),
        encoding="utf-8",
    )
    with pytest.raises(ScriptError, match="generated blocks are stale"):
        licenses.check_all(project)
    regenerate(project)
    licenses.check_all(project)


def test_source_offer_derives_urls_from_runtime_manifest() -> None:
    manifest = json.loads((PROJECT_DIR / "runtime.json").read_text(encoding="utf-8"))
    offer = licenses.render_source_offer(manifest)

    assert manifest["buildRecipe"]["url"] in offer
    assert manifest["buildRecipe"]["sha256"] in offer
    assert manifest["provenance"]["nixpkgsCommit"] in offer
    assert licenses.release_url(manifest["runtime"]["url"]) in offer
    assert "does not cover today" in offer


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


def test_license_texts_page_holds_every_text_once(project: Path) -> None:
    (project / "docs/legal/licenses/example.txt").write_text(
        "MIT text\n```\nfence", encoding="utf-8"
    )
    page = licenses.generate_documents(project)[licenses.LICENSE_TEXTS_DOCUMENT]

    assert "### pkg" in page
    assert "### lib" in page
    assert "````text\nMIT text\n```\nfence\n````" in page
    assert page.count("MIT text") == 1
    assert "The text of `example.txt` is under [pkg](#pkg)." in page
    assert "### Art" not in page


def test_license_texts_page_merges_runtime_index(project: Path, tmp_path: Path) -> None:
    runtime = make_runtime(tmp_path)
    page = licenses.generate_documents(project, runtime)[
        licenses.LICENSE_TEXTS_DOCUMENT
    ]

    assert "### Lib" in page
    assert "Runtime notice" in page
    assert "This page does not list the runtime license index" not in page
    assert licenses.generate_documents(project)[licenses.LICENSE_TEXTS_DOCUMENT] != page


def test_stale_license_texts_page_fails_and_generate_repairs_it(
    project: Path,
) -> None:
    (project / "docs/legal/licenses/example.txt").write_text(
        "Changed text", encoding="utf-8"
    )
    with pytest.raises(
        ScriptError, match="license-texts.md: generated blocks are stale"
    ):
        licenses.check_all(project)
    regenerate(project)
    licenses.check_all(project)


def test_check_with_runtime_detects_a_page_without_runtime_texts(
    project: Path, tmp_path: Path
) -> None:
    runtime = make_runtime(tmp_path)
    with pytest.raises(
        ScriptError, match="license-texts.md: generated blocks are stale"
    ):
        licenses.check_all(project, runtime)
    regenerate(project, runtime)
    assert licenses.check_all(project, runtime) == [
        "Art 1.0.0: license not yet verified"
    ]


def test_runtime_without_index_warns_and_strict_fails(
    project: Path, tmp_path: Path
) -> None:
    runtime = tmp_path / "runtime"
    runtime.mkdir()

    assert licenses.check_all(project, runtime)[0] == (
        "the runtime has no Licenses/index.json"
    )
    with pytest.raises(ScriptError, match="no Licenses/index.json"):
        licenses.check_all(project, runtime, strict=True)


def test_strict_fails_on_unverified_runtime_component(
    project: Path, tmp_path: Path
) -> None:
    rewrite(project, lambda document: document["components"].pop())
    (project / "Sources/ArknightsClient/Resources/Art.png").unlink()
    runtime = make_runtime(tmp_path, status="unverified")
    regenerate(project, runtime)

    assert licenses.check_all(project, runtime)
    with pytest.raises(ScriptError, match="Lib 1.0.0: license not yet verified"):
        licenses.check_all(project, runtime, strict=True)


def test_runtime_index_with_missing_text_fails(project: Path, tmp_path: Path) -> None:
    runtime = make_runtime(tmp_path)
    (runtime / "Licenses/runtime/MIT.txt").unlink()
    with pytest.raises(ScriptError, match="lists missing file runtime/MIT.txt"):
        licenses.check_all(project, runtime)


def test_bundle_writes_one_compiled_file_with_runtime_components(
    project: Path, tmp_path: Path
) -> None:
    resources = tmp_path / "Resources"
    resources.mkdir()
    runtime = make_runtime(tmp_path)

    warnings = licenses.stage_bundle(project, resources, runtime, strict=False)

    assert [path.name for path in resources.iterdir()] == ["ThirdPartyNotices.deflate"]
    notices = licenses.compiled_text(resources / "ThirdPartyNotices.deflate")
    assert notices is not None
    assert "[Lib](" in notices
    assert "Runtime notice" in notices
    assert "licenses:begin" not in notices
    assert warnings == ["Art 1.0.0: license not yet verified"]


def test_compiled_notices_keep_each_distinct_text_once(project: Path) -> None:
    (project / "docs/legal/licenses/same.txt").write_text("MIT text", encoding="utf-8")
    rewrite(
        project,
        lambda document: (
            document["components"].append(
                component(name="Twin", files=["same.txt"], spdx="MIT")
            ),
            document["textOrigins"].update({"same.txt": "test"}),
        ),
    )
    components = licenses.load_client_components(project, [])

    notices = licenses.render_compiled_notices(project, components, None)

    assert notices.count("MIT text") == 1
    assert notices.count("| `MIT` |") == 2


def test_compiled_notices_exclude_website_components(project: Path) -> None:
    components = licenses.load_client_components(project, [])

    notices = licenses.render_compiled_notices(project, components, None)

    assert "[lib](" not in notices
    assert "[pkg](" in notices


def test_missing_or_stale_compiled_notices_fail_the_check(project: Path) -> None:
    compiled = project / licenses.COMPILED_NOTICES
    compiled.write_bytes(licenses.compress_notices("old"))
    with pytest.raises(ScriptError, match="compiled notices are missing or stale"):
        licenses.check_all(project)
    compiled.unlink()
    with pytest.raises(ScriptError, match="compiled notices are missing or stale"):
        licenses.check_all(project)
    assert licenses.write_compiled_notices(project)
    assert not licenses.write_compiled_notices(project)
    licenses.check_all(project)


def test_staging_runtime_legal_rejects_symlinks(tmp_path: Path) -> None:
    archive = tmp_path / "archive"
    (archive / "Licenses").mkdir(parents=True)
    (archive / "Licenses/link.txt").symlink_to("/etc/hosts")
    runtime = tmp_path / "runtime"
    runtime.mkdir()

    with pytest.raises(ScriptError, match="regular file"):
        licenses.stage_runtime_legal(archive, runtime)


def test_staging_runtime_legal_copies_files(tmp_path: Path) -> None:
    archive = tmp_path / "archive"
    shutil.copytree(make_runtime(tmp_path) / "Licenses", archive / "Licenses")
    (archive / "NOTICE.md").write_text("n", encoding="utf-8")
    runtime = tmp_path / "prepared"
    runtime.mkdir()

    assert licenses.stage_runtime_legal(archive, runtime)
    assert (runtime / "Licenses/index.json").is_file()
    assert (runtime / "NOTICE.md").is_file()
    assert not licenses.stage_runtime_legal(tmp_path / "empty", runtime)


def test_strict_bundle_fails_without_runtime_index(
    project: Path, tmp_path: Path
) -> None:
    resources = tmp_path / "Resources"
    resources.mkdir()
    runtime = tmp_path / "runtime"
    runtime.mkdir()

    warnings = licenses.stage_bundle(project, resources, runtime, strict=False)

    assert warnings[0] == "the runtime archive has no Licenses/index.json"
    with pytest.raises(ScriptError, match="no Licenses/index.json"):
        licenses.stage_bundle(project, resources, runtime, strict=True)

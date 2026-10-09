# SPDX-License-Identifier: MPL-2.0

"""Validate, merge, and render the third-party license inventory.

Two indexes use one component schema. The client index lives in
`docs/legal/licenses/index.json` and lists SwiftPM packages, website packages, and
bundled resources. The runtime index is `Licenses/index.json` inside the runtime
archive. The generator fills the generated blocks of the notice, source-offer, and
license-text documents that the website publishes. It also compiles one compact
notices file for the app bundle: each distinct license text appears once, and the
whole file is raw-deflate compressed.
"""

from __future__ import annotations

import json
import re
import shutil
import zlib
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from lib.common import fail, safe_relative_path

SCHEMA_VERSION = 1
VERIFIED = "verified"
UNVERIFIED = "unverified"
APP_SCOPE = "app"
WEBSITE_SCOPE = "website"
LEGACY_RUNTIME_SCOPE = "runtime-legacy"
RUNTIME_SCOPE = "runtime"
CLIENT_SCOPES = (APP_SCOPE, WEBSITE_SCOPE, LEGACY_RUNTIME_SCOPE)
ECOSYSTEMS = ("swiftpm", "npm")

LICENSE_DIRECTORY = Path("docs/legal/licenses")
CLIENT_INDEX = LICENSE_DIRECTORY / "index.json"
NOTICES_DOCUMENT = Path("docs/legal/third-party-notices.md")
SOURCE_DOCUMENT = Path("docs/legal/source-code.md")
LICENSE_TEXTS_DOCUMENT = Path("docs/legal/license-texts.md")
COMPILED_NOTICES = Path("docs/legal/ThirdPartyNotices.deflate")
BUNDLE_NOTICES_NAME = "ThirdPartyNotices.deflate"
SITE_URL = "https://lumisxh.github.io/Arknights-MacOS-Client/"
RESOURCE_DIRECTORY = Path("Sources/ArknightsClient/Resources")
RUNTIME_LICENSE_DIRECTORY = "Licenses"
RUNTIME_NOTICE_FILE = "NOTICE.md"

BLOCK_PATTERN = re.compile(
    r"<!-- licenses:begin (?P<name>[a-z-]+) -->\n(?P<body>.*?)<!-- licenses:end (?P=name) -->\n",
    re.DOTALL,
)


@dataclass(frozen=True)
class Component:
    """One third-party or bundled component and its license evidence."""

    name: str
    version: str
    spdx: str
    source: str
    files: tuple[str, ...]
    status: str
    scope: str
    basis: str | None = None
    notice: str | None = None
    candidates: tuple[str, ...] = ()
    ecosystem: str | None = None
    package: str | None = None
    paths: tuple[str, ...] = ()
    note: str | None = None

    @property
    def is_verified(self) -> bool:
        return self.status == VERIFIED


@dataclass(frozen=True)
class RuntimeLegal:
    """The license index, notice, and directory a runtime archive carries."""

    components: tuple[Component, ...]
    license_directory: Path
    notice: Path | None


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"unable to read {path}: {error}")


def runtime_source(manifest: Mapping[str, Any], key: str) -> str:
    """Return the pinned source tree URL of a `runtime.json` component."""
    provenance = manifest["provenance"]
    repository = provenance[f"{key}Repository"]
    commit = provenance[f"{key}Commit"]
    tree = (
        "/-/tree/" if urlparse(repository).hostname == "gitlab.winehq.org" else "/tree/"
    )
    return f"{repository}{tree}{commit}"


def parse_components(
    raw: object,
    label: str,
    scopes: tuple[str, ...],
    problems: list[str],
    manifest: Mapping[str, Any] | None = None,
) -> tuple[Component, ...]:
    """Validate raw index entries; append every defect to `problems`."""
    if not isinstance(raw, list) or not raw:
        problems.append(f"{label}: components must be a non-empty list")
        return ()
    components: list[Component] = []
    for position, entry in enumerate(raw):
        where = f"{label}: component {position}"
        if not isinstance(entry, dict):
            problems.append(f"{where} must be an object")
            continue
        name = entry.get("name")
        where = f"{label}: {name!r}" if isinstance(name, str) and name else where
        before = len(problems)
        text = {
            key: _text(entry, key, where, problems)
            for key in ("name", "spdx", "status", "basis", "notice", "note")
        }
        text["scope"] = _text(entry, "scope", where, problems) or scopes[0]
        derived = _text(entry, "runtimeComponent", where, problems)
        version = _text(entry, "version", where, problems)
        source = _text(entry, "source", where, problems)
        if derived is not None:
            try:
                assert manifest is not None
                version = version or manifest["components"][derived]
                source = source or runtime_source(manifest, derived)
            except AssertionError, KeyError, TypeError:
                problems.append(f"{where}: runtimeComponent {derived!r} is not pinned")
        for key, value in (("name", text["name"]), ("spdx", text["spdx"])):
            if not value:
                problems.append(f"{where}: {key} is required")
        if not version or not source or not source.startswith("https://"):
            problems.append(f"{where}: version and an HTTPS source are required")
        if text["status"] not in (VERIFIED, UNVERIFIED):
            problems.append(f"{where}: status must be verified or unverified")
        if text["status"] == VERIFIED and not text["basis"]:
            problems.append(f"{where}: a verified component needs a basis")
        if text["scope"] not in scopes:
            problems.append(f"{where}: scope must be one of {', '.join(scopes)}")
        files = _paths(entry.get("files"), "files", where, problems)
        paths = _paths(entry.get("paths", []), "paths", where, problems)
        candidates = _strings(
            entry.get("candidates", []), "candidates", where, problems
        )
        if text["notice"]:
            _paths([text["notice"]], "notice", where, problems)
        ecosystem = _text(entry, "ecosystem", where, problems)
        package = _text(entry, "package", where, problems)
        if ecosystem is not None and (ecosystem not in ECOSYSTEMS or not package):
            problems.append(f"{where}: ecosystem needs a package and a known name")
        if len(problems) == before:
            components.append(
                Component(
                    name=text["name"] or "",
                    version=version or "",
                    spdx=text["spdx"] or "",
                    source=source or "",
                    files=files,
                    status=text["status"] or "",
                    scope=text["scope"],
                    basis=text["basis"],
                    notice=text["notice"],
                    candidates=candidates,
                    ecosystem=ecosystem,
                    package=package,
                    paths=paths,
                    note=text["note"],
                )
            )
    names = [component.name for component in components]
    for duplicate in sorted({name for name in names if names.count(name) > 1}):
        problems.append(f"{label}: duplicate component {duplicate!r}")
    return tuple(components)


def _text(
    entry: Mapping[str, Any], key: str, where: str, problems: list[str]
) -> str | None:
    value = entry.get(key)
    if value is None:
        return None
    if not isinstance(value, str):
        problems.append(f"{where}: {key} must be a string")
        return None
    return value


def _strings(
    value: object, key: str, where: str, problems: list[str]
) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        problems.append(f"{where}: {key} must be a list of strings")
        return ()
    return tuple(value)


def _paths(value: object, key: str, where: str, problems: list[str]) -> tuple[str, ...]:
    checked: list[str] = []
    for item in _strings(value, key, where, problems):
        try:
            checked.append(
                safe_relative_path(item, f"{where}: unsafe {key} path {item!r}")
            )
        except ValueError as error:
            problems.append(str(error))
    return tuple(checked)


def load_client_components(root: Path, problems: list[str]) -> tuple[Component, ...]:
    document = read_json(root / CLIENT_INDEX)
    if (
        not isinstance(document, dict)
        or document.get("schemaVersion") != SCHEMA_VERSION
    ):
        problems.append(f"{CLIENT_INDEX}: schemaVersion must be {SCHEMA_VERSION}")
        return ()
    manifest = read_json(root / "runtime.json")
    return parse_components(
        document.get("components"), str(CLIENT_INDEX), CLIENT_SCOPES, problems, manifest
    )


def load_runtime_legal(
    runtime: Path | None, problems: list[str]
) -> RuntimeLegal | None:
    """Read the license index of a prepared runtime; None when it carries none."""
    if runtime is None:
        return None
    directory = runtime / RUNTIME_LICENSE_DIRECTORY
    index = directory / "index.json"
    if not index.is_file():
        return None
    label = f"runtime {RUNTIME_LICENSE_DIRECTORY}/index.json"
    document = read_json(index)
    if (
        not isinstance(document, dict)
        or document.get("schemaVersion") != SCHEMA_VERSION
    ):
        problems.append(f"{label}: schemaVersion must be {SCHEMA_VERSION}")
        return None
    components = parse_components(
        document.get("components"), label, (RUNTIME_SCOPE,), problems
    )
    for component in components:
        for relative in (
            *component.files,
            *([component.notice] if component.notice else []),
        ):
            if (
                not (directory / relative).is_file()
                or (directory / relative).is_symlink()
            ):
                problems.append(
                    f"{label}: {component.name!r} lists missing file {relative}"
                )
    notice = runtime / RUNTIME_NOTICE_FILE
    return RuntimeLegal(components, directory, notice if notice.is_file() else None)


def swiftpm_pins(root: Path) -> dict[str, str]:
    document = read_json(root / "Package.resolved")
    return {pin["identity"]: pin["state"]["version"] for pin in document["pins"]}


def website_dependencies(root: Path) -> dict[str, str]:
    """Return the packages that the built website embeds, with their pinned version."""
    manifest = read_json(root / "web/package.json")
    versions = {**manifest["dependencies"], **manifest.get("devDependencies", {})}
    return {name: re.sub(r"^.*#v?", "", version) for name, version in versions.items()}


def check_inventory(root: Path, components: tuple[Component, ...]) -> list[str]:
    """Cross-check the client index against the files that declare what ships."""
    problems: list[str] = []
    pins = swiftpm_pins(root)
    packages = {c.package: c for c in components if c.ecosystem == "swiftpm"}
    for identity, version in sorted(pins.items()):
        entry = packages.get(identity)
        if entry is None:
            problems.append(
                f"Package.resolved: {identity} {version} has no index entry"
            )
        elif entry.version != version:
            problems.append(
                f"Package.resolved: {identity} is {version}, the index says {entry.version}"
            )
    problems.extend(
        f"{CLIENT_INDEX}: swiftpm package {name} is not in Package.resolved"
        for name in sorted(set(packages) - set(pins))
    )

    manifest = read_json(root / "web/package.json")
    shipped = {c.package: c for c in components if c.ecosystem == "npm"}
    versions = website_dependencies(root)
    for name in sorted(manifest["dependencies"]):
        if name not in shipped:
            problems.append(f"web/package.json: {name} has no index entry")
    for name, entry in sorted(shipped.items()):
        if versions.get(name) != entry.version:
            problems.append(
                f"web/package.json: {name} is {versions.get(name)}, the index says {entry.version}"
            )

    covered = {path for component in components for path in component.paths}
    resources = root / RESOURCE_DIRECTORY
    problems.extend(
        f"{RESOURCE_DIRECTORY}/{path.name}: bundled resource has no index entry"
        for path in sorted(resources.iterdir())
        if path.name not in covered
    )
    problems.extend(
        f"{CLIENT_INDEX}: {name} is not in {RESOURCE_DIRECTORY}"
        for name in sorted(covered - {path.name for path in resources.iterdir()})
    )

    directory = root / LICENSE_DIRECTORY
    origins = read_json(root / CLIENT_INDEX).get("textOrigins", {})
    referenced = {file for component in components for file in component.files}
    problems.extend(
        f"{CLIENT_INDEX}: textOrigins has no entry for {name}"
        for name in sorted(referenced - set(origins))
    )
    problems.extend(
        f"{LICENSE_DIRECTORY}/{name}: listed text file is missing"
        for name in sorted(referenced)
        if not (directory / name).is_file()
    )
    problems.extend(
        f"{LICENSE_DIRECTORY}/{path.name}: license text has no index entry"
        for path in sorted(directory.glob("*.txt"))
        if path.name not in referenced
    )
    return problems


def unverified(components: Iterable[Component]) -> list[Component]:
    return [component for component in components if not component.is_verified]


def _license_cell(component: Component) -> str:
    if component.is_verified:
        return f"`{component.spdx}`"
    if component.candidates:
        return (
            "License not yet verified (candidates: "
            + ", ".join(f"`{value}`" for value in component.candidates)
            + ")"
        )
    return "License not yet verified"


def render_table(components: Iterable[Component], link: str, notes: bool = True) -> str:
    """Render a Markdown table; `link` is the folder that holds the license texts."""
    lines = [
        "| Component | Version | License | Status | Text |",
        "| --- | --- | --- | --- | --- |",
    ]
    for component in components:
        texts = ", ".join(
            f"[`{Path(file).name}`]({link}{file})" if link else f"`{file}`"
            for file in component.files
        )
        label = f"[{component.name}]({component.source})"
        if notes and component.note:
            label += f" {component.note}"
        status = "Verified" if component.is_verified else "Not yet verified"
        lines.append(
            f"| {label} | {component.version} | {_license_cell(component)} | {status} | {texts or 'None'} |"
        )
    return "\n".join(lines) + "\n"


def render_launcher_block(components: tuple[Component, ...], link: str) -> str:
    app = [c for c in components if c.scope == APP_SCOPE]
    return (
        "## Launcher components\n\n"
        "These components ship inside the app. `Not yet verified` means that the project "
        "has not confirmed the license of the component.\n\n" + render_table(app, link)
    )


def render_website_block(components: tuple[Component, ...], link: str) -> str:
    website = [c for c in components if c.scope == WEBSITE_SCOPE]
    return (
        "## Website components\n\n"
        "The documentation website embeds these packages. They are not part of the app. "
        "The website build also embeds the transitive dependencies of these packages. Each "
        "dependency keeps its own license.\n\n" + render_table(website, link)
    )


def render_runtime_block() -> str:
    """Render the runtime section of the notices document."""
    return (
        "## Runtime components\n\n"
        "The runtime archive lists its components and their licenses in "
        f"`{RUNTIME_LICENSE_DIRECTORY}/index.json`. The [license texts](license-texts.md) "
        "page merges that list with the launcher components when the maintainer generates "
        "it with a prepared runtime.\n"
    )


def release_url(archive_url: str) -> str:
    """Map a release asset URL to the page of its release."""
    match = re.fullmatch(
        r"(https://github\.com/[^/]+/[^/]+)/releases/download/([^/]+)/[^/]+",
        archive_url,
    )
    if match is None:
        fail(f"cannot derive the release page from {archive_url}")
    return f"{match[1]}/releases/tag/{match[2]}"


def render_source_offer(manifest: Mapping[str, Any]) -> str:
    """Render the written source offer from the facts in `runtime.json`."""
    recipe = manifest["buildRecipe"]
    provenance = manifest["provenance"]
    release = release_url(manifest["runtime"]["url"])
    nixpkgs = f"{provenance['nixpkgsRepository']}/tree/{provenance['nixpkgsCommit']}"
    return (
        "## Written offer for LGPL and GPL components\n\n"
        "The runtime contains software under the GNU LGPL and GNU GPL licenses. Wine is "
        "one example. You can ask for the corresponding source of any such component in "
        "a release that you received. To ask, open an issue in the "
        "[Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues). "
        "Name the version of the app and the component. The maintainer then sends the "
        "source or the exact public location of the source.\n\n"
        "### What this offer covers today\n\n"
        f"- The runtime release page: [{release}]({release}).\n"
        f"- The pinned build recipe archive: [{recipe['url']}]({recipe['url']}). Its "
        f"SHA-256 is `{recipe['sha256']}`.\n"
        "- The pinned source trees of the runtime components, as `runtime.json` records "
        "them. [Third-party notices](third-party-notices.md) links each tree.\n"
        f"- The pinned [Nixpkgs revision]({nixpkgs}). It names the exact source of each "
        "library that the runtime copies from Nixpkgs.\n\n"
        "### What this offer does not cover today\n\n"
        "- The build recipe archive is a provenance record. It is not a complete "
        "corresponding-source archive.\n"
        "- The project has not yet published one source archive for the libraries that "
        "the runtime copies from Nixpkgs. The runtime repository still has this work "
        "open. Until the project publishes that archive, the written offer for these "
        "libraries uses the issue process above.\n"
        "- This text does not fix a period of validity for the offer. The maintainer "
        "must set that period before a public binary release.\n"
    )


def apply_blocks(text: str, blocks: Mapping[str, str], keep_markers: bool) -> str:
    """Replace the body of each generated block; fail on a missing or unknown block."""
    seen: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        name = match["name"]
        if name not in blocks:
            fail(f"unknown generated block: {name}")
        seen.add(name)
        body = blocks[name]
        if not keep_markers:
            return body
        return f"<!-- licenses:begin {name} -->\n{body}<!-- licenses:end {name} -->\n"

    result = BLOCK_PATTERN.sub(replace, text)
    missing = sorted(set(blocks) - seen)
    if missing:
        fail(f"generated block not found in document: {', '.join(missing)}")
    return result


def document_blocks(
    components: tuple[Component, ...], manifest: Mapping[str, Any]
) -> tuple[dict[str, str], dict[str, str]]:
    """Return the generated blocks of the notices and the source documents."""
    notices = {
        "launcher": render_launcher_block(components, "licenses/"),
        "website": render_website_block(components, "licenses/"),
        "runtime": render_runtime_block(),
    }
    return notices, {"offer": render_source_offer(manifest)}


class _Slugger:
    """Mirror the heading ids of the website so that links to a component work."""

    def __init__(self) -> None:
        self._used: dict[str, int] = {}

    def slug(self, heading: str) -> str:
        base = re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")
        count = self._used.get(base)
        self._used[base] = (count or 0) + 1
        return base if count is None else f"{base}-{count}"


def _fenced(text: str) -> str:
    """Wrap text in a code fence that no line of the text can close."""
    body = text.replace("\r\n", "\n").strip("\n")
    longest = max((len(run) for run in re.findall(r"`+", body)), default=0)
    fence = "`" * max(3, longest + 1)
    return f"{fence}text\n{body}\n{fence}\n"


def render_license_texts(
    root: Path, components: tuple[Component, ...], legal: RuntimeLegal | None
) -> str:
    """Render the full license text of every component with a text file.

    Each component has a heading. An identical text file appears once and later
    components link to it. The runtime section merges the runtime index when `legal`
    is present.
    """
    manifest = read_json(root / "runtime.json")
    slugger = _Slugger()
    printed: dict[Path, tuple[str, str]] = {}

    def section(
        title: str, intro: str, members: Iterable[Component], directory: Path
    ) -> str:
        slugger.slug(title)
        text = f"## {title}\n\n{intro}\n\n"
        for member in members:
            files = (*member.files, *([member.notice] if member.notice else []))
            if not files:
                continue
            anchor = slugger.slug(member.name)
            text += f"### {member.name}\n\n"
            text += (
                f"Version {member.version}. {_license_cell(member)}. "
                f"[Source]({member.source}).\n\n"
            )
            for file in files:
                path = directory / file
                if path in printed:
                    owner, owner_anchor = printed[path]
                    text += (
                        f"The text of `{Path(file).name}` is under "
                        f"[{owner}](#{owner_anchor}).\n\n"
                    )
                    continue
                printed[path] = (member.name, anchor)
                text += (
                    f"Text: `{Path(file).name}`\n\n"
                    + _fenced(path.read_text(encoding="utf-8"))
                    + "\n"
                )
        return text

    directory = root / LICENSE_DIRECTORY
    parts = [
        section(
            "Launcher components",
            "These components ship inside the app. Project-owned resources use the "
            "license of the repository and have no separate text.",
            (c for c in components if c.scope == APP_SCOPE),
            directory,
        ),
        section(
            "Website components",
            "The documentation website embeds these packages. They are not part of the app.",
            (c for c in components if c.scope == WEBSITE_SCOPE),
            directory,
        ),
    ]
    if legal is None:
        release = release_url(manifest["runtime"]["url"])
        parts.append(
            section(
                "Runtime components",
                "> [!WARNING]\n"
                "> This page does not list the runtime license index. The components below "
                "come from `runtime.json` and the project's own records. They are not a "
                "complete component list. The runtime archive carries its own license "
                f"texts in `{RUNTIME_LICENSE_DIRECTORY}/`. See the "
                f"[runtime release]({release}).",
                (c for c in components if c.scope == LEGACY_RUNTIME_SCOPE),
                directory,
            )
        )
    else:
        parts.append(
            section(
                "Runtime components",
                "The runtime archive supplies this list.",
                legal.components,
                legal.license_directory,
            )
        )
        if legal.notice is not None:
            slugger.slug("Runtime notice")
            parts.append(
                "### Runtime notice\n\n"
                + _fenced(legal.notice.read_text(encoding="utf-8"))
                + "\n"
            )
    return "".join(parts).rstrip("\n") + "\n"


def generate_documents(root: Path, runtime: Path | None = None) -> dict[Path, str]:
    """Return the repository documents with up-to-date generated blocks."""
    problems: list[str] = []
    components = load_client_components(root, problems)
    legal = load_runtime_legal(runtime, problems)
    if problems:
        fail("\n".join(problems))
    manifest = read_json(root / "runtime.json")
    notices, source = document_blocks(components, manifest)
    texts = {"texts": render_license_texts(root, components, legal)}
    documents = (
        (NOTICES_DOCUMENT, notices),
        (SOURCE_DOCUMENT, source),
        (LICENSE_TEXTS_DOCUMENT, texts),
    )
    return {
        path: apply_blocks((root / path).read_text(encoding="utf-8"), blocks, True)
        for path, blocks in documents
    }


def check_all(
    root: Path, runtime: Path | None = None, strict: bool = False
) -> list[str]:
    """Return warnings after every consistency check passes; fail on any problem.

    Strict mode also fails on an unverified component and on a runtime without a
    license index or notice.
    """
    problems: list[str] = []
    components = load_client_components(root, problems)
    legal = load_runtime_legal(runtime, problems)
    if not problems:
        problems.extend(check_inventory(root, components))
    if not problems:
        for path, expected in generate_documents(root, runtime).items():
            if (root / path).read_text(encoding="utf-8") != expected:
                problems.append(
                    f"{path}: generated blocks are stale; run scripts/licenses.py"
                )
        if compiled_text(root / COMPILED_NOTICES) != render_compiled_notices(
            root, components, legal
        ):
            problems.append(
                f"{COMPILED_NOTICES}: compiled notices are missing or stale; "
                "run scripts/licenses.py"
            )
    warnings = _unverified_warnings([*components, *(legal.components if legal else ())])
    if runtime is not None and legal is None:
        warnings.insert(0, f"the runtime has no {RUNTIME_LICENSE_DIRECTORY}/index.json")
    elif legal is not None and legal.notice is None:
        warnings.insert(0, f"the runtime has no {RUNTIME_NOTICE_FILE}")
    if strict and warnings:
        problems.extend(warnings)
        warnings = []
    if problems:
        fail("\n".join(problems))
    return warnings


def _text_id(spdx: str, taken: Iterable[str]) -> str:
    base = re.sub(r"[^A-Za-z0-9.+-]+", "-", spdx).strip("-") or "license"
    used = set(taken)
    candidate, number = base, 2
    while candidate in used:
        candidate, number = f"{base}-{number}", number + 1
    return candidate


def render_compiled_notices(
    root: Path, components: tuple[Component, ...], legal: RuntimeLegal | None
) -> str:
    """Render the notices that the app shows: component tables and each text once.

    Components reference a license text by its id. Two files with identical content
    share one entry. The app never ships the website-only components.
    """
    members: list[tuple[str, Component, Path]] = [
        ("Launcher components", c, root / LICENSE_DIRECTORY)
        for c in components
        if c.scope == APP_SCOPE
    ]
    runtime_members = (
        [(c, legal.license_directory) for c in legal.components]
        if legal is not None
        else [
            (c, root / LICENSE_DIRECTORY)
            for c in components
            if c.scope == LEGACY_RUNTIME_SCOPE
        ]
    )
    members += [("Runtime components", c, d) for c, d in runtime_members]

    ids_by_text: dict[str, str] = {}
    bodies: dict[str, str] = {}

    def reference(component: Component, directory: Path, file: str) -> str:
        text = (directory / file).read_text(encoding="utf-8").replace("\r\n", "\n")
        if text not in ids_by_text:
            identifier = _text_id(component.spdx, bodies)
            ids_by_text[text] = identifier
            bodies[identifier] = text
        return ids_by_text[text]

    sections: dict[str, list[str]] = {}
    for title, component, directory in members:
        references = ", ".join(
            f"`{reference(component, directory, file)}`" for file in component.files
        )
        label = f"[{component.name}]({component.source})"
        if component.note:
            label += f" {component.note}"
        sections.setdefault(title, []).append(
            f"| {label} | {component.version} | {_license_cell(component)} "
            f"| {references or 'None'} |"
        )
    text = (
        "# Third-party notices\n\n"
        "This file lists the third-party components of the app and holds each license "
        f"text once. The same content is on the website: {SITE_URL}legal/third-party-notices/ "
        f"and {SITE_URL}legal/license-texts/. The source offer is at "
        f"{SITE_URL}legal/source-code/.\n\n"
    )
    for title, rows in sections.items():
        text += (
            f"## {title}\n\n| Component | Version | License | Text |\n"
            "| --- | --- | --- | --- |\n" + "\n".join(rows) + "\n\n"
        )
    text += "## License texts\n\n"
    for identifier, body in bodies.items():
        text += f"### {identifier}\n\n{_fenced(body)}\n"
    if legal is not None and legal.notice is not None:
        text += "### Runtime notice\n\n" + _fenced(
            legal.notice.read_text(encoding="utf-8")
        )
    return text.rstrip("\n") + "\n"


def compress_notices(text: str) -> bytes:
    """Return raw deflate data, which Apple's Compression framework reads as zlib."""
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    return compressor.compress(text.encode("utf-8")) + compressor.flush()


def compiled_text(path: Path) -> str | None:
    """Return the text inside a compiled notices file; None if it is missing or bad."""
    try:
        return zlib.decompress(path.read_bytes(), -15).decode("utf-8")
    except OSError, zlib.error, UnicodeDecodeError:
        return None


def write_compiled_notices(root: Path, runtime: Path | None = None) -> bool:
    """Rewrite the committed compiled file when it differs; return True if changed."""
    problems: list[str] = []
    components = load_client_components(root, problems)
    legal = load_runtime_legal(runtime, problems)
    if problems:
        fail("\n".join(problems))
    text = render_compiled_notices(root, components, legal)
    target = root / COMPILED_NOTICES
    if compiled_text(target) == text:
        return False
    target.write_bytes(compress_notices(text))
    return True


def stage_bundle(
    root: Path, resources: Path, runtime: Path | None, strict: bool
) -> list[str]:
    """Write the compiled notices into an app `Resources` directory.

    Return the warnings. In strict mode a missing runtime index, a missing runtime
    notice, or an unverified component in the app or runtime fails the build.
    """
    problems: list[str] = []
    components = load_client_components(root, problems)
    legal = load_runtime_legal(runtime, problems)
    if not problems:
        problems.extend(check_inventory(root, components))
    if problems:
        fail("\n".join(problems))

    shipped = [c for c in components if c.scope == APP_SCOPE]
    if legal is None:
        shipped.extend(c for c in components if c.scope == LEGACY_RUNTIME_SCOPE)
    else:
        shipped.extend(legal.components)
    warnings = _unverified_warnings(shipped)
    if legal is None:
        warnings.insert(0, "the runtime archive has no Licenses/index.json")
    elif legal.notice is None:
        warnings.insert(0, f"the runtime archive has no {RUNTIME_NOTICE_FILE}")
    if strict and warnings:
        fail("strict license check failed:\n" + "\n".join(warnings))

    text = render_compiled_notices(root, components, legal)
    (resources / BUNDLE_NOTICES_NAME).write_bytes(compress_notices(text))
    return warnings


def _unverified_warnings(components: Iterable[Component]) -> list[str]:
    return [
        f"{component.name} {component.version}: license not yet verified"
        for component in unverified(components)
    ]


def stage_runtime_legal(archive_root: Path, runtime: Path) -> bool:
    """Copy the archive's `Licenses/` and `NOTICE.md` into the prepared runtime."""
    licenses = archive_root / RUNTIME_LICENSE_DIRECTORY
    if not licenses.is_dir():
        return False
    for path in licenses.rglob("*"):
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            fail(f"runtime license path must be a regular file or directory: {path}")
    shutil.copytree(licenses, runtime / RUNTIME_LICENSE_DIRECTORY)
    notice = archive_root / RUNTIME_NOTICE_FILE
    if notice.is_file() and not notice.is_symlink():
        shutil.copyfile(notice, runtime / RUNTIME_NOTICE_FILE)
    return True

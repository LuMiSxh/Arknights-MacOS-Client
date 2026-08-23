# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import pytest
import runtime_config
from lib.common import PROJECT_DIR


def valid_config() -> dict[str, object]:
    value = json.loads((PROJECT_DIR / "runtime.json").read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def write_config(path: Path, value: dict[str, object]) -> None:
    path.write_text(json.dumps(value), encoding="utf-8")


def test_reads_nested_scalar(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, {"runtime": {"url": "https://example.com/runtime.tar.gz"}})

    assert (
        runtime_config.read_value(config, "runtime.url")
        == "https://example.com/runtime.tar.gz"
    )


def test_rejects_missing_value(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    write_config(config, {})

    with pytest.raises(RuntimeError):
        runtime_config.read_value(config, "runtime.url")


def test_validates_complete_configuration(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    write_config(config, value)

    loaded = runtime_config.load_runtime_config(config)

    assert loaded.runtime_url == value["runtime"]["url"]
    assert (
        dict(loaded.layout.dxmt.destinations)
        == value["interface"]["dxmt"]["destinations"]
    )


def test_rejects_invalid_checksum(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    assert isinstance(value["runtime"], dict)
    value["runtime"]["sha256"] = "latest"
    write_config(config, value)

    with pytest.raises(RuntimeError):
        runtime_config.validate_config(config)


def test_rejects_previous_schema(tmp_path: Path) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    value["schemaVersion"] = 1
    write_config(config, value)

    with pytest.raises(RuntimeError, match="schemaVersion must be 2"):
        runtime_config.validate_config(config)


def test_new_component_requires_and_accepts_matching_provenance(
    tmp_path: Path,
) -> None:
    config = tmp_path / "runtime.json"
    value = valid_config()
    assert isinstance(value["components"], dict)
    assert isinstance(value["provenance"], dict)
    value["components"]["newMedia"] = "2"
    write_config(config, value)

    with pytest.raises(RuntimeError, match="missing component sources"):
        runtime_config.validate_config(config)

    value["provenance"]["newMediaRepository"] = "https://example.com/media"
    value["provenance"]["newMediaCommit"] = "1" * 40
    write_config(config, value)
    runtime_config.validate_config(config)

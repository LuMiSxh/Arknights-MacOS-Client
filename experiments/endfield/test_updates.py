# SPDX-License-Identifier: MPL-2.0

"""Fixture-backed tests for game update detection and config.ini decryption."""

import copy
import json
import urllib.parse
from pathlib import Path

import gamecrypt
import installer
import pytest
import updates

FIXTURES = Path(__file__).parent / "fixtures"
LATEST_FIXTURE = FIXTURES / "get_latest_patch.json"
CONFIG_FIXTURE = FIXTURES / "config.ini.enc"


def test_aes256_decrypts_the_fips_197_block() -> None:
    key = bytes.fromhex(
        "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    )
    cipher = bytes.fromhex("8ea2b7ca516745bfeafc49904b496089")
    assert (
        gamecrypt.decrypt_cbc(key, bytes(16), cipher, unpad=False).hex()
        == "00112233445566778899aabbccddeeff"
    )


def test_config_ini_fixture_decrypts_to_the_game_section() -> None:
    plain = gamecrypt.decrypt_config(CONFIG_FIXTURE.read_bytes())
    assert gamecrypt.parse_ini(plain.decode())["Game"] == {
        "version": "1.3.7",
        "entry": "Endfield.exe",
        "entry_md5": "00112233445566778899aabbccddeeff",
        "appcode": "YDUTE5gscDZ229CW",
        "region": "sg",
        "channel": "6",
        "sub_channel": "6",
    }


def test_installed_game_reads_the_version_from_config_ini(tmp_path: Path) -> None:
    (tmp_path / "config.ini").write_bytes(CONFIG_FIXTURE.read_bytes())
    installed = updates.installed_game(tmp_path)
    assert (installed.version, installed.entry, installed.appcode) == (
        "1.3.7",
        "Endfield.exe",
        "YDUTE5gscDZ229CW",
    )


def test_parse_latest_reads_the_full_package_and_patch() -> None:
    latest = updates.parse_latest(json.loads(LATEST_FIXTURE.read_text()))
    assert (latest.version, latest.action, latest.state) == ("1.7.2", 1, 0)
    assert latest.package is not None
    assert latest.package.total_size == 139623810121
    assert [pack.size for pack in latest.package.packs] == [1073741824, 1073741824]
    assert latest.patch is not None
    assert latest.patch.patch_info_size == 2048
    assert latest.patch.verify_size == 4096
    assert latest.patch.verify_md5 == "fedcba9876543210fedcba9876543210"
    assert latest.patch.cd_key == "patch-password"
    assert latest.patch.total_size == 987654321
    assert [url.rsplit("/", 1)[-1] for url in latest.patch.urls] == [
        "Beyond_1.7.1_to_1.7.2.zip",
        "Beyond_1.7.1_to_1.7.2_vfs.zip",
    ]
    assert latest.pre_patch is None


def test_parse_latest_rejects_a_patch_on_a_foreign_host() -> None:
    document = copy.deepcopy(json.loads(LATEST_FIXTURE.read_text()))
    document["patch"]["v2_verify_files_url"] = "https://evil.example/v2_verify_files"
    with pytest.raises(installer.InstallError):
        updates.parse_latest(document)


def test_latest_url_has_no_device_id_and_names_the_launcher() -> None:
    query = urllib.parse.parse_qs(
        urllib.parse.urlsplit(updates.latest_url("1.7.1")).query
    )
    assert query == {
        "appcode": ["YDUTE5gscDZ229CW"],
        "launcher_appcode": ["TiaytKBUIEdoEwRT"],
        "channel": ["6"],
        "sub_channel": ["6"],
        "launcher_sub_channel": ["6"],
        "disk_type": ["0"],
        "patch_encrypt": ["true"],
        "version": ["1.7.1"],
    }


@pytest.mark.parametrize(
    ("version", "older"),
    [("1.7.2", "1.7.1"), ("1.7.1", "1.7.0"), ("1.7.0", None), ("1.7", None)],
)
def test_older_version_decrements_only_a_positive_patch(version, older) -> None:
    assert updates.older_version(version) == older

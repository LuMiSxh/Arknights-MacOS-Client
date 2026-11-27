# SPDX-License-Identifier: MPL-2.0

"""Decrypt the game's small encrypted manifests.

Endfield encrypts ``config.ini`` and the ``game_files`` manifest with AES-256-CBC. The
key is a hex string; the IV is the hex form of its decimal-looking ASCII digits. Both
are the same for every install. Ciphertexts are PKCS#7 padded.

The lab carries its own AES so the experiment needs no package. Swift ports this to
CommonCrypto's ``kCCAlgorithmAES`` with the same key and IV.
"""

from functools import lru_cache

CONFIG_KEY_HEX = "c0f30e1ce763bbc21cc355a34303ac50399444bff68c4a22af398c0a166ee143"
CONFIG_IV_HEX = "33467861192750649501937264608400"
BLOCK_SIZE = 16
ROUNDS = 14


def _gf_mul(left: int, right: int) -> int:
    product = 0
    while right:
        if right & 1:
            product ^= left
        left = ((left << 1) ^ 0x1B) & 0xFF if left & 0x80 else (left << 1) & 0xFF
        right >>= 1
    return product


def _gf_pow(base: int, exponent: int) -> int:
    result = 1
    while exponent:
        if exponent & 1:
            result = _gf_mul(result, base)
        base = _gf_mul(base, base)
        exponent >>= 1
    return result


def _rotate_left(value: int, places: int) -> int:
    return ((value << places) | (value >> (8 - places))) & 0xFF


def _build_sbox() -> tuple[list[int], list[int]]:
    sbox = []
    for value in range(256):
        inverse = 0 if value == 0 else _gf_pow(value, 254)
        sbox.append(
            inverse
            ^ _rotate_left(inverse, 1)
            ^ _rotate_left(inverse, 2)
            ^ _rotate_left(inverse, 3)
            ^ _rotate_left(inverse, 4)
            ^ 0x63
        )
    inverse_sbox = [0] * 256
    for index, value in enumerate(sbox):
        inverse_sbox[value] = index
    return sbox, inverse_sbox


SBOX, INVERSE_SBOX = _build_sbox()
MULTIPLY_9 = [_gf_mul(value, 9) for value in range(256)]
MULTIPLY_11 = [_gf_mul(value, 11) for value in range(256)]
MULTIPLY_13 = [_gf_mul(value, 13) for value in range(256)]
MULTIPLY_14 = [_gf_mul(value, 14) for value in range(256)]


@lru_cache(maxsize=4)
def _round_keys(key: bytes) -> tuple[tuple[int, ...], ...]:
    if len(key) != 32:
        raise ValueError("AES-256 needs a 32-byte key")
    words = [list(key[offset : offset + 4]) for offset in range(0, 32, 4)]
    rcon = 1
    for index in range(8, 4 * (ROUNDS + 1)):
        word = words[index - 1][:]
        if index % 8 == 0:
            word = [SBOX[byte] for byte in word[1:] + word[:1]]
            word[0] ^= rcon
            rcon = _gf_mul(rcon, 2)
        elif index % 8 == 4:
            word = [SBOX[byte] for byte in word]
        words.append([words[index - 8][slot] ^ word[slot] for slot in range(4)])
    return tuple(
        tuple(byte for word in words[round * 4 : round * 4 + 4] for byte in word)
        for round in range(ROUNDS + 1)
    )


def _inv_shift_rows(state: list[int]) -> list[int]:
    shifted = [0] * BLOCK_SIZE
    for row in range(4):
        for column in range(4):
            shifted[4 * column + row] = state[4 * ((column - row) % 4) + row]
    return shifted


def _inv_mix_columns(state: list[int]) -> list[int]:
    mixed = [0] * BLOCK_SIZE
    for column in range(4):
        a0, a1, a2, a3 = state[4 * column : 4 * column + 4]
        mixed[4 * column : 4 * column + 4] = [
            MULTIPLY_14[a0] ^ MULTIPLY_11[a1] ^ MULTIPLY_13[a2] ^ MULTIPLY_9[a3],
            MULTIPLY_9[a0] ^ MULTIPLY_14[a1] ^ MULTIPLY_11[a2] ^ MULTIPLY_13[a3],
            MULTIPLY_13[a0] ^ MULTIPLY_9[a1] ^ MULTIPLY_14[a2] ^ MULTIPLY_11[a3],
            MULTIPLY_11[a0] ^ MULTIPLY_13[a1] ^ MULTIPLY_9[a2] ^ MULTIPLY_14[a3],
        ]
    return mixed


def _decrypt_block(key: bytes, block: bytes) -> bytes:
    keys = _round_keys(key)
    state = [byte ^ round_byte for byte, round_byte in zip(block, keys[ROUNDS])]
    for round_number in range(ROUNDS - 1, 0, -1):
        state = _inv_shift_rows(state)
        state = [INVERSE_SBOX[byte] for byte in state]
        state = [
            byte ^ round_byte for byte, round_byte in zip(state, keys[round_number])
        ]
        state = _inv_mix_columns(state)
    state = _inv_shift_rows(state)
    state = [INVERSE_SBOX[byte] for byte in state]
    return bytes(byte ^ round_byte for byte, round_byte in zip(state, keys[0]))


def _unpad(padded: bytes) -> bytes:
    pad = padded[-1]
    if not 0 < pad <= BLOCK_SIZE or padded[-pad:] != bytes([pad]) * pad:
        raise ValueError("invalid PKCS#7 padding")
    return padded[:-pad]


def decrypt_cbc(key: bytes, iv: bytes, data: bytes, *, unpad: bool = True) -> bytes:
    """Decrypt AES-256-CBC data and remove PKCS#7 padding unless ``unpad`` is false."""
    if not data or len(data) % BLOCK_SIZE:
        raise ValueError("ciphertext is not a non-empty multiple of the block size")
    if len(key) != 32 or len(iv) != BLOCK_SIZE:
        raise ValueError("AES-256-CBC needs a 32-byte key and a 16-byte IV")
    plain = bytearray()
    previous = iv
    for offset in range(0, len(data), BLOCK_SIZE):
        block = data[offset : offset + BLOCK_SIZE]
        plain.extend(
            left ^ right for left, right in zip(_decrypt_block(key, block), previous)
        )
        previous = block
    return _unpad(bytes(plain)) if unpad else bytes(plain)


def decrypt_config(data: bytes) -> bytes:
    """Decrypt a ``config.ini`` or ``game_files`` blob with the install-wide key."""
    return decrypt_cbc(
        bytes.fromhex(CONFIG_KEY_HEX), bytes.fromhex(CONFIG_IV_HEX), data
    )


def parse_ini(text: str) -> dict[str, dict[str, str]]:
    """Read ``[section]`` and ``key=value`` lines into a nested dict."""
    sections: dict[str, dict[str, str]] = {}
    current: dict[str, str] | None = None
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped[0] in ";#":
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            current = sections.setdefault(stripped[1:-1], {})
        elif current is not None and "=" in stripped:
            key, _, value = stripped.partition("=")
            current[key.strip()] = value.strip()
    return sections

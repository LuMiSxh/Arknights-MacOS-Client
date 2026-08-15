// SPDX-License-Identifier: MPL-2.0

#include <windows.h>
#include <wincrypt.h>
#include <wchar.h>
#include <wctype.h>

/*
 * Wine 11.15 does not implement
 * DeriveAppContainerSidFromAppContainerName(), but Chromium imports it when
 * preparing the sandbox used by OAuth pop-ups. Wine aborts the Vuplex helper
 * at that import, before Google or Facebook can display a page.
 *
 * This DLL supplies only that missing API. Windows derives an AppContainer SID
 * by lowercasing the moniker, hashing its UTF-16 bytes with SHA-256, and using
 * the first seven little-endian DWORDs below the S-1-15-2 authority. Wine does
 * not create an AppContainer token for this process; the SID only lets
 * Chromium finish its compatibility checks instead of hitting Wine's
 * unimplemented-function trap.
 *
 * The launcher installs this file beside the official Vuplex helper. Its
 * wrapper adds a process-local WINEDLLOVERRIDES entry before starting that
 * helper, so the replacement cannot affect Arknights, DXMT, or unrelated Wine
 * processes. The marker is intentionally retained for safe upgrade/removal.
 */
__declspec(dllexport) const char arknights_client_userenv_marker[] =
	"Arknights Client AppContainer compatibility";

static HRESULT result_from_last_error(void) {
	DWORD error = GetLastError();

	if (error == ERROR_SUCCESS) error = ERROR_GEN_FAILURE;
	return HRESULT_FROM_WIN32(error);
}

__declspec(dllexport)
HRESULT WINAPI DeriveAppContainerSidFromAppContainerName(
	PCWSTR app_container_name,
	PSID *app_container_sid
) {
	SID_IDENTIFIER_AUTHORITY authority = SECURITY_APP_PACKAGE_AUTHORITY;
	HCRYPTPROV provider = 0;
	HCRYPTHASH hash = 0;
	wchar_t *normalized_name = NULL;
	DWORD digest[8];
	DWORD digest_size = sizeof(digest);
	size_t name_length;
	size_t index;
	HRESULT result = E_FAIL;

	if (app_container_sid == NULL) return E_POINTER;
	*app_container_sid = NULL;
	if (app_container_name == NULL || app_container_name[0] == L'\0') {
		return E_INVALIDARG;
	}

	name_length = wcslen(app_container_name);
	if (name_length > (MAXDWORD / sizeof(*normalized_name)) - 1) {
		return HRESULT_FROM_WIN32(ERROR_ARITHMETIC_OVERFLOW);
	}
	normalized_name = HeapAlloc(
		GetProcessHeap(),
		0,
		(name_length + 1) * sizeof(*normalized_name)
	);
	if (normalized_name == NULL) return E_OUTOFMEMORY;
	for (index = 0; index < name_length; index++) {
		normalized_name[index] = towlower(app_container_name[index]);
	}
	normalized_name[name_length] = L'\0';

	if (!CryptAcquireContextW(
			&provider,
			NULL,
			NULL,
			PROV_RSA_AES,
			CRYPT_VERIFYCONTEXT
		)
		|| !CryptCreateHash(provider, CALG_SHA_256, 0, 0, &hash)
		|| !CryptHashData(
			hash,
			(const BYTE *)normalized_name,
			(DWORD)(name_length * sizeof(*normalized_name)),
			0
		)
		|| !CryptGetHashParam(hash, HP_HASHVAL, (BYTE *)digest, &digest_size, 0)) {
		result = result_from_last_error();
		goto cleanup;
	}
	if (digest_size != sizeof(digest)) {
		result = E_UNEXPECTED;
		goto cleanup;
	}
	if (!AllocateAndInitializeSid(
			&authority,
			SECURITY_APP_PACKAGE_RID_COUNT,
			SECURITY_APP_PACKAGE_BASE_RID,
			digest[0],
			digest[1],
			digest[2],
			digest[3],
			digest[4],
			digest[5],
			digest[6],
			app_container_sid
		)) {
		result = result_from_last_error();
		goto cleanup;
	}
	result = S_OK;

cleanup:
	if (hash != 0) CryptDestroyHash(hash);
	if (provider != 0) CryptReleaseContext(provider, 0);
	HeapFree(GetProcessHeap(), 0, normalized_name);
	return result;
}

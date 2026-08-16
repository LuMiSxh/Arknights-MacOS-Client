// SPDX-License-Identifier: MPL-2.0

#include <windows.h>
#include <wincrypt.h>
#include <wchar.h>
#include <wctype.h>

/*
 * Wine 11.15 does not implement AppContainer APIs in userenv.dll.
 * Chromium's sandbox (sandbox/win/src/app_container_base.cc) dynamically
 * loads these functions via GetProcAddress and asserts CHECK(fn).
 *
 * This DLL supplies stubs for all required AppContainer APIs to prevent
 * Chromium from throwing FATAL CHECK assertions.
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

__declspec(dllexport)
HRESULT WINAPI CreateAppContainerProfile(
	PCWSTR app_container_name,
	PCWSTR display_name,
	PCWSTR description,
	PSID_AND_ATTRIBUTES capabilities,
	DWORD capability_count,
	PSID *app_container_sid
) {
	(void)display_name;
	(void)description;
	(void)capabilities;
	(void)capability_count;
	return DeriveAppContainerSidFromAppContainerName(app_container_name, app_container_sid);
}

__declspec(dllexport)
HRESULT WINAPI DeleteAppContainerProfile(
	PCWSTR app_container_name
) {
	(void)app_container_name;
	return S_OK;
}

__declspec(dllexport)
HRESULT WINAPI GetAppContainerRegistryLocation(
	REGSAM desired_access,
	PHKEY app_container_key
) {
	(void)desired_access;
	if (app_container_key == NULL) return E_POINTER;
	*app_container_key = NULL;
	return E_NOTIMPL;
}

__declspec(dllexport)
HRESULT WINAPI GetAppContainerFolderPath(
	PCWSTR app_container_sid,
	PWSTR *folder_path
) {
	(void)app_container_sid;
	if (folder_path == NULL) return E_POINTER;
	*folder_path = NULL;
	return E_NOTIMPL;
}

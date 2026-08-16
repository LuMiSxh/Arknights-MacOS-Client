// SPDX-License-Identifier: MPL-2.0

#include <windows.h>
#include <shellapi.h>
#include <strsafe.h>
#include <wchar.h>

/*
 * Arknights starts this file as Vuplex WebView.vuplex. During launch, the
 * native macOS client moves the official helper beside it under
 * original_name and installs this small wrapper at the original path.
 *
 * The official helper uses Chromium Embedded Framework. Its accelerated
 * off-screen rendering path can share a D3D11 texture with the Unity process.
 * DXMT can create that shared resource, but Chromium and Vuplex attempt to
 * write it concurrently through this runtime and the browser remains blank.
 * The wrapper therefore selects Vuplex's CPU OnPaint transfer while leaving
 * Chromium's own GPU compositor, WebGL, and rasterization available. These
 * arguments affect only the helper process; Arknights keeps its own DXMT
 * device and renderer.
 *
 * Wine's global Windows DPI changes Unity's initial window geometry. The
 * native launcher therefore keeps the prefix at 96 DPI and exports
 * ARKNIGHTS_CLIENT_BROWSER_SCALE_FACTOR instead. When its value is 2, this
 * wrapper asks Chromium alone for a 2x device scale factor. This gives the
 * off-screen browser a high-density paint buffer without changing the game
 * window's coordinate system.
 *
 * CEF's asynchronous DNS resolver asks Windows to sort IPv6 destinations
 * through SIO_ADDRESS_LIST_SORT. Wine currently returns WSAEOPNOTSUPP for
 * that ioctl, and CEF retries it while an OAuth page appears blank. Disabling
 * only AsyncDns makes CEF use Wine's regular system resolver instead; it does
 * not disable networking or change DNS behavior for the game process.
 *
 * Chromium also imports DeriveAppContainerSidFromAppContainerName() for its
 * OAuth sandbox. That API is absent from the tested Wine runtime. The wrapper
 * therefore adds a process-local userenv native override before creating the
 * official helper. The matching compatibility DLL implements only that one
 * derivation API and is never loaded by the game process.
 *
 * The wrapper preserves every argument supplied by the game, appends only
 * missing compatibility arguments, starts the untouched official helper, and
 * returns its exit code. Installation is reversible, and unknown helper
 * versions are never replaced by the launcher.
 *
 * launcher_marker is a stable ownership signature used by the native client
 * to recognize this wrapper across upgrades. Keep the marker in future
 * versions even if the backup filename or compatibility arguments change.
 */
static const volatile char launcher_marker[] = "Arknights Client Vuplex compatibility";
static const wchar_t original_name[] = L"Vuplex WebView.original.helper.vuplex";
static const wchar_t userenv_override[] = L"userenv=n,b";
static const wchar_t *compatibility_arguments[] = {
	L"--vx-accelerated-paint-disabled",
	L"--disable-features=AsyncDns",
};
static const wchar_t *high_resolution_arguments[] = {
	L"--high-dpi-support=1",
	L"--force-device-scale-factor=2",
};

static wchar_t *module_path(void) {
	DWORD capacity = 1024;

	for (;;) {
		wchar_t *path = GlobalAlloc(GMEM_FIXED, (SIZE_T)capacity * sizeof(*path));
		DWORD length;

		if (path == NULL) return NULL;
		length = GetModuleFileNameW(NULL, path, capacity);
		if (length == 0) {
			GlobalFree(path);
			return NULL;
		}
		if (length < capacity - 1) return path;
		GlobalFree(path);
		if (capacity > (MAXDWORD / 2)) {
			SetLastError(ERROR_FILENAME_EXCED_RANGE);
			return NULL;
		}
		capacity *= 2;
	}
}

static BOOL has_argument(int count, wchar_t **arguments, const wchar_t *expected) {
	int index;

	for (index = 1; index < count; index++) {
		if (wcscmp(arguments[index], expected) == 0) return TRUE;
	}
	return FALSE;
}

static BOOL high_resolution_enabled(void) {
	wchar_t value[8];
	DWORD length = GetEnvironmentVariableW(
		L"ARKNIGHTS_CLIENT_BROWSER_SCALE_FACTOR",
		value,
		ARRAYSIZE(value)
	);

	return length == 1 && value[0] == L'2';
}

static wchar_t *append_quoted(wchar_t *destination, const wchar_t *argument) {
	const wchar_t *cursor = argument;
	size_t backslashes = 0;

	*destination++ = L'"';
	while (*cursor != L'\0') {
		if (*cursor == L'\\') {
			backslashes++;
			cursor++;
			continue;
		}
		if (*cursor == L'"') {
			while (backslashes > 0) {
				backslashes--;
				*destination++ = L'\\';
				*destination++ = L'\\';
			}
			*destination++ = L'\\';
			*destination++ = L'"';
			cursor++;
			continue;
		}
		while (backslashes > 0) {
			backslashes--;
			*destination++ = L'\\';
		}
		*destination++ = *cursor++;
	}
	while (backslashes > 0) {
		backslashes--;
		*destination++ = L'\\';
		*destination++ = L'\\';
	}
	*destination++ = L'"';
	return destination;
}

static BOOL enable_userenv_override(void) {
	static const wchar_t variable_name[] = L"WINEDLLOVERRIDES";
	DWORD existing_length = GetEnvironmentVariableW(variable_name, NULL, 0);
	wchar_t *value;
	SIZE_T value_length;
	BOOL result;
	HRESULT string_result;

	if (existing_length == 0) {
		return SetEnvironmentVariableW(variable_name, userenv_override);
	}
	value_length = (SIZE_T)existing_length + wcslen(userenv_override) + 1;
	value = GlobalAlloc(GMEM_FIXED, value_length * sizeof(*value));
	if (value == NULL) return FALSE;
	if (GetEnvironmentVariableW(variable_name, value, existing_length) == 0) {
		GlobalFree(value);
		return FALSE;
	}
	string_result = StringCchCatW(value, value_length, L";");
	if (SUCCEEDED(string_result)) {
		string_result = StringCchCatW(value, value_length, userenv_override);
	}
	if (FAILED(string_result)) {
		GlobalFree(value);
		SetLastError(ERROR_INSUFFICIENT_BUFFER);
		return FALSE;
	}
	result = SetEnvironmentVariableW(variable_name, value);
	GlobalFree(value);
	return result;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous_instance, LPSTR command_line, int show_command) {
	wchar_t *shim_path = NULL;
	wchar_t *original_path = NULL;
	wchar_t *child_command_line = NULL;
	wchar_t **arguments = NULL;
	wchar_t *cursor;
	wchar_t *separator;
	int argument_count;
	int index;
	int compatibility_index;
	int high_resolution_index;
	BOOL use_high_resolution;
	SIZE_T command_length = 1;
	STARTUPINFOW startup_info = { .cb = sizeof(startup_info) };
	PROCESS_INFORMATION process_info = { 0 };
	DWORD exit_code;
	DWORD error;
	SIZE_T original_capacity;
	HRESULT string_result;

	(void)instance;
	(void)previous_instance;
	(void)command_line;
	(void)show_command;
	if (launcher_marker[0] == '\0') return ERROR_INVALID_DATA;
	shim_path = module_path();
	if (shim_path == NULL) return (int)GetLastError();
	separator = wcsrchr(shim_path, L'\\');
	if (separator == NULL) separator = wcsrchr(shim_path, L'/');
	if (separator == NULL) {
		GlobalFree(shim_path);
		return ERROR_PATH_NOT_FOUND;
	}
	separator[1] = L'\0';
	original_capacity = wcslen(shim_path) + wcslen(original_name) + 1;
	original_path = GlobalAlloc(GMEM_FIXED, original_capacity * sizeof(*original_path));
	if (original_path == NULL) {
		GlobalFree(shim_path);
		return ERROR_NOT_ENOUGH_MEMORY;
	}
	string_result = StringCchCopyW(original_path, original_capacity, shim_path);
	if (SUCCEEDED(string_result)) {
		string_result = StringCchCatW(original_path, original_capacity, original_name);
	}
	GlobalFree(shim_path);
	if (FAILED(string_result)) {
		GlobalFree(original_path);
		return ERROR_INSUFFICIENT_BUFFER;
	}
	arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
	if (arguments == NULL) {
		error = GetLastError();
		GlobalFree(original_path);
		return (int)error;
	}
	use_high_resolution = high_resolution_enabled();
	command_length += 2 * wcslen(original_path) + 3;
	for (index = 1; index < argument_count; index++) command_length += 2 * wcslen(arguments[index]) + 3;
	for (compatibility_index = 0; compatibility_index < ARRAYSIZE(compatibility_arguments); compatibility_index++) {
		if (!has_argument(argument_count, arguments, compatibility_arguments[compatibility_index])) {
			command_length += 2 * wcslen(compatibility_arguments[compatibility_index]) + 3;
		}
	}
	if (use_high_resolution) {
		for (high_resolution_index = 0; high_resolution_index < ARRAYSIZE(high_resolution_arguments); high_resolution_index++) {
			if (!has_argument(argument_count, arguments, high_resolution_arguments[high_resolution_index])) {
				command_length += 2 * wcslen(high_resolution_arguments[high_resolution_index]) + 3;
			}
		}
	}
	child_command_line = GlobalAlloc(GMEM_FIXED, command_length * sizeof(*child_command_line));
	if (child_command_line == NULL) {
		LocalFree(arguments);
		GlobalFree(original_path);
		return ERROR_NOT_ENOUGH_MEMORY;
	}
	cursor = append_quoted(child_command_line, original_path);
	for (index = 1; index < argument_count; index++) {
		*cursor++ = L' ';
		cursor = append_quoted(cursor, arguments[index]);
	}
	for (compatibility_index = 0; compatibility_index < ARRAYSIZE(compatibility_arguments); compatibility_index++) {
		if (!has_argument(argument_count, arguments, compatibility_arguments[compatibility_index])) {
			*cursor++ = L' ';
			cursor = append_quoted(cursor, compatibility_arguments[compatibility_index]);
		}
	}
	if (use_high_resolution) {
		for (high_resolution_index = 0; high_resolution_index < ARRAYSIZE(high_resolution_arguments); high_resolution_index++) {
			if (!has_argument(argument_count, arguments, high_resolution_arguments[high_resolution_index])) {
				*cursor++ = L' ';
				cursor = append_quoted(cursor, high_resolution_arguments[high_resolution_index]);
			}
		}
	}
	*cursor = L'\0';
	LocalFree(arguments);
	if (!enable_userenv_override()) {
		error = GetLastError();
		GlobalFree(child_command_line);
		GlobalFree(original_path);
		return (int)error;
	}
	if (!CreateProcessW(original_path, child_command_line, NULL, NULL, FALSE, 0, NULL, NULL, &startup_info, &process_info)) {
		error = GetLastError();
		GlobalFree(child_command_line);
		GlobalFree(original_path);
		return (int)error;
	}
	WaitForSingleObject(process_info.hProcess, INFINITE);
	if (!GetExitCodeProcess(process_info.hProcess, &exit_code)) exit_code = GetLastError();
	CloseHandle(process_info.hThread);
	CloseHandle(process_info.hProcess);
	GlobalFree(child_command_line);
	GlobalFree(original_path);
	return (int)exit_code;
}

/* SPDX-License-Identifier: MPL-2.0 */

#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <wchar.h>

/*
 * Window-lifecycle wrapper for Arknights' Qt-based Notices helper.
 *
 * PlatformProcess.exe creates its notice as a top-level window in a separate
 * Windows and Unix process. Wine consequently presents it to macOS as an
 * independent application: it receives another Dock entry, can remain on a
 * different Space, and does not follow the game through normal owner-window
 * behavior.
 *
 * The launcher preserves the official executable beside this wrapper. The
 * wrapper forwards every original argument, injects the adjacent process-local
 * AppKit bridge through WineCX's __CX_UNIX_ environment passthrough, and keeps
 * the helper aligned with the game through Win32 coordinates. Moving the Cocoa
 * window directly would leave Wine's hit-testing coordinates stale. It never
 * reads or modifies page content.
 */

static const volatile char launcher_marker[] =
	"Arknights Client PlatformProcess compatibility";
static const wchar_t original_name[] = L"PlatformProcess.original.helper.exe";
static const wchar_t bridge_name[] = L"PlatformProcessWindowBridge.dylib";

typedef char *(CDECL *wine_get_unix_file_name_fn)(const wchar_t *path);

struct window_search {
	DWORD process_id;
	HWND result;
};

struct game_window_search {
	DWORD excluded_process_id;
	HWND result;
	LONG64 largest_area;
};

/* Win32 gives no fixed upper bound for a module's own path, so this grows the buffer
 * and retries until GetModuleFileNameW stops truncating. */
static wchar_t *module_path(void) {
	DWORD capacity = 1024;

	for (;;) {
		wchar_t *path = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)capacity * sizeof(*path));
		DWORD length;

		if (path == NULL) return NULL;
		length = GetModuleFileNameW(NULL, path, capacity);
		if (length == 0) {
			HeapFree(GetProcessHeap(), 0, path);
			return NULL;
		}
		if (length < capacity - 1) return path;
		HeapFree(GetProcessHeap(), 0, path);
		if (capacity > MAXDWORD / 2) return NULL;
		capacity *= 2;
	}
}

/* Builds the path to `name` in the same directory as `module` (the original helper or the
 * bridge dylib both live beside this shim). Returns NULL if `module` has no directory
 * separator, which should never happen for a path GetModuleFileNameW returns. */
static wchar_t *sibling_path(const wchar_t *module, const wchar_t *name) {
	const wchar_t *separator = wcsrchr(module, L'\\');
	SIZE_T directory_length;
	SIZE_T bytes;
	wchar_t *result;

	if (separator == NULL) separator = wcsrchr(module, L'/');
	if (separator == NULL) return NULL;
	directory_length = (SIZE_T)(separator - module + 1);
	bytes = (directory_length + wcslen(name) + 1) * sizeof(*result);
	result = HeapAlloc(GetProcessHeap(), 0, bytes);
	if (result == NULL) return NULL;
	memcpy(result, module, directory_length * sizeof(*result));
	wcscpy(result + directory_length, name);
	return result;
}

/* Appends `argument` to `destination` using the same quoting rules CommandLineToArgvW
 * expects on the other end: backslashes are only doubled when they immediately precede a
 * quote (or end the argument before the closing quote), so paths with plain backslashes
 * round-trip unchanged while an embedded `"` or a trailing `\` doesn't break the split.
 * Caller must have already sized `destination` for the worst case (2x length + quotes). */
static wchar_t *append_quoted(wchar_t *destination, const wchar_t *argument) {
	const wchar_t *cursor = argument;
	SIZE_T backslashes = 0;

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

/* EnumWindows callback: picks the first visible top-level window owned by the child
 * process that's at least 400x300, which filters out Qt's incidental tooltip/tool windows
 * and leaves the real notice window. */
static BOOL CALLBACK find_process_window(HWND window, LPARAM context_value) {
	struct window_search *search = (struct window_search *)context_value;
	DWORD process_id = 0;
	RECT rectangle;

	GetWindowThreadProcessId(window, &process_id);
	if (process_id != search->process_id || !IsWindowVisible(window)) return TRUE;
	if (!GetWindowRect(window, &rectangle)) return TRUE;
	if (rectangle.right - rectangle.left < 400 || rectangle.bottom - rectangle.top < 300) return TRUE;
	search->result = window;
	return FALSE;
}

/* EnumWindows callback: keeps the largest visible window titled "Arknights" that isn't
 * owned by this wrapper's own child process, since the game may briefly own more than one
 * window (splash, loading) and only the largest is the actual game window worth tracking. */
static BOOL CALLBACK find_game_window(HWND window, LPARAM context_value) {
	struct game_window_search *search = (struct game_window_search *)context_value;
	DWORD process_id = 0;
	wchar_t title[128];
	RECT rectangle;
	LONG64 area;

	GetWindowThreadProcessId(window, &process_id);
	if (process_id == search->excluded_process_id || !IsWindowVisible(window)) return TRUE;
	if (GetWindowTextW(window, title, ARRAYSIZE(title)) == 0) return TRUE;
	if (wcsncmp(title, L"Arknights", 9) != 0) return TRUE;
	if (!GetWindowRect(window, &rectangle)) return TRUE;
	area = (LONG64)(rectangle.right - rectangle.left) *
		(LONG64)(rectangle.bottom - rectangle.top);
	if (area <= search->largest_area) return TRUE;
	search->largest_area = area;
	search->result = window;
	return TRUE;
}

/* Wraps find_game_window's EnumWindows scan; `excluded_process_id` is this wrapper's own
 * child (the notice helper), never the game itself. */
static HWND locate_game_window(DWORD excluded_process_id) {
	struct game_window_search search = { excluded_process_id, NULL, 0 };

	EnumWindows(find_game_window, (LPARAM)&search);
	return search.result;
}

/* Qt creates the notice window bordered and non-activating by default. Strips
 * WS_BORDER/WS_DLGFRAME/WS_THICKFRAME and WS_EX_NOACTIVATE so it matches the borderless,
 * interactive treatment the macOS-side bridge applies, then forces a frame-changed repaint
 * only if a style bit actually changed (SetWindowPos is otherwise a visible no-op flicker). */
static HWND repair_notice_window(DWORD process_id) {
	struct window_search search = { process_id, NULL };
	LONG_PTR style;
	LONG_PTR extended_style;
	BOOL style_changed = FALSE;

	EnumWindows(find_process_window, (LPARAM)&search);
	if (search.result == NULL) return NULL;
	style = GetWindowLongPtrW(search.result, GWL_STYLE);
	if ((style & (WS_BORDER | WS_DLGFRAME | WS_THICKFRAME)) != 0) {
		style &= ~(WS_BORDER | WS_DLGFRAME | WS_THICKFRAME);
		SetWindowLongPtrW(search.result, GWL_STYLE, style);
		style_changed = TRUE;
	}
	extended_style = GetWindowLongPtrW(search.result, GWL_EXSTYLE);
	if ((extended_style & WS_EX_NOACTIVATE) != 0) {
		extended_style &= ~WS_EX_NOACTIVATE;
		SetWindowLongPtrW(search.result, GWL_EXSTYLE, extended_style);
		style_changed = TRUE;
	}
	if (style_changed) {
		SetWindowPos(
			search.result,
			NULL,
			0,
			0,
			0,
			0,
			SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOZORDER | SWP_FRAMECHANGED
		);
	}
	return search.result;
}

/* Records the notice window's current position relative to the game window, so whatever
 * placement the user (or Qt) chose is preserved instead of snapping to a fixed corner. */
static BOOL capture_notice_offset(HWND notice, HWND game, POINT *offset) {
	RECT game_rectangle;
	RECT notice_rectangle;

	if (!GetWindowRect(game, &game_rectangle) || !GetWindowRect(notice, &notice_rectangle)) {
		return FALSE;
	}
	offset->x = notice_rectangle.left - game_rectangle.left;
	offset->y = notice_rectangle.top - game_rectangle.top;
	return TRUE;
}

/* Repositions the notice window to keep the captured offset from the game window, skipping
 * SetWindowPos entirely when already at the target (avoids per-tick redundant moves while
 * the game window is stationary). Returns FALSE on a failed rect query so the caller
 * recaptures the offset next tick instead of drifting from a stale one. */
static BOOL follow_game_window(HWND notice, HWND game, POINT offset) {
	RECT game_rectangle;
	RECT notice_rectangle;
	int target_x;
	int target_y;

	if (!GetWindowRect(game, &game_rectangle) || !GetWindowRect(notice, &notice_rectangle)) {
		return FALSE;
	}
	target_x = game_rectangle.left + offset.x;
	target_y = game_rectangle.top + offset.y;
	if (notice_rectangle.left == target_x && notice_rectangle.top == target_y) return TRUE;
	return SetWindowPos(
		notice,
		NULL,
		target_x,
		target_y,
		0,
		0,
		SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOZORDER
	);
}

/* Resolves the bridge dylib's Wine path to its real Unix path via
 * wine_get_unix_file_name, then arranges for it to be DYLD-injected into the child Unix
 * process this shim is about to spawn. */
static BOOL install_bridge_environment(const wchar_t *bridge_path) {
	HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
	wine_get_unix_file_name_fn convert;
	char *unix_path;
	BOOL result;

	if (GetFileAttributesW(bridge_path) == INVALID_FILE_ATTRIBUTES || kernel32 == NULL) {
		return FALSE;
	}
	convert = (wine_get_unix_file_name_fn)GetProcAddress(kernel32, "wine_get_unix_file_name");
	if (convert == NULL) return FALSE;
	unix_path = convert(bridge_path);
	if (unix_path == NULL) return FALSE;
	/* WineCX promotes __CX_UNIX_* values into the Unix child environment. */
	result = SetEnvironmentVariableA("__CX_UNIX_DYLD_INSERT_LIBRARIES", unix_path);
	HeapFree(GetProcessHeap(), 0, unix_path);
	return result;
}

/* Locates the original helper and bridge dylib beside this shim, injects the bridge into
 * the child's environment, rebuilds the original command line unchanged, and launches the
 * real PlatformProcess.exe. While it runs, polls for the notice and game windows (fast
 * 50ms until both are found, then 8ms) and keeps the notice positioned relative to the
 * game window, since Wine gives it no owner-window relationship to do this automatically.
 * Exits with the child's exit code once it terminates. */
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, wchar_t *command_line, int show) {
	wchar_t *module = NULL;
	wchar_t *original = NULL;
	wchar_t *bridge = NULL;
	wchar_t *child_command = NULL;
	wchar_t **arguments = NULL;
	wchar_t *cursor;
	int argument_count = 0;
	int index;
	SIZE_T command_length;
	STARTUPINFOW startup = { .cb = sizeof(startup) };
	PROCESS_INFORMATION process = { 0 };
	DWORD exit_code = ERROR_GEN_FAILURE;
	DWORD wait_timeout = 100;
	HWND notice = NULL;
	HWND game = NULL;
	POINT notice_offset = { 0 };
	BOOL has_notice_offset = FALSE;
	BOOL reported_windows = FALSE;

	(void)instance;
	(void)previous;
	(void)command_line;
	(void)show;
	if (launcher_marker[0] == '\0') return ERROR_INVALID_DATA;

	module = module_path();
	if (module == NULL) goto cleanup;
	original = sibling_path(module, original_name);
	bridge = sibling_path(module, bridge_name);
	if (original == NULL || bridge == NULL) goto cleanup;
	if (!install_bridge_environment(bridge)) goto cleanup;

	arguments = CommandLineToArgvW(GetCommandLineW(), &argument_count);
	if (arguments == NULL) goto cleanup;
	command_length = 2 * wcslen(original) + 3;
	for (index = 1; index < argument_count; index++) {
		command_length += 2 * wcslen(arguments[index]) + 3;
	}
	child_command = HeapAlloc(GetProcessHeap(), 0, command_length * sizeof(*child_command));
	if (child_command == NULL) goto cleanup;
	cursor = append_quoted(child_command, original);
	for (index = 1; index < argument_count; index++) {
		*cursor++ = L' ';
		cursor = append_quoted(cursor, arguments[index]);
	}
	*cursor = L'\0';

	if (!CreateProcessW(original, child_command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &process)) {
		exit_code = GetLastError();
		goto cleanup;
	}
	for (;;) {
		DWORD wait = WaitForSingleObject(process.hProcess, wait_timeout);

		if (wait == WAIT_OBJECT_0) break;
		if (wait == WAIT_FAILED) goto cleanup;
		if (notice == NULL || !IsWindow(notice)) {
			notice = repair_notice_window(process.dwProcessId);
			has_notice_offset = FALSE;
		}
		if (game == NULL || !IsWindow(game)) {
			game = locate_game_window(process.dwProcessId);
			has_notice_offset = FALSE;
		}
		if (notice == NULL || game == NULL) {
			wait_timeout = 50;
			continue;
		}
		if (!reported_windows) {
			fprintf(
				stderr,
				"platform-window-wrapper: notice=%p style=%08lx exstyle=%08lx game=%p\n",
				notice,
				(unsigned long)GetWindowLongPtrW(notice, GWL_STYLE),
				(unsigned long)GetWindowLongPtrW(notice, GWL_EXSTYLE),
				game
			);
			reported_windows = TRUE;
		}
		if (!has_notice_offset) {
			has_notice_offset = capture_notice_offset(notice, game, &notice_offset);
		} else if (!follow_game_window(notice, game, notice_offset)) {
			has_notice_offset = FALSE;
		}
		wait_timeout = 8;
	}
	if (!GetExitCodeProcess(process.hProcess, &exit_code)) exit_code = GetLastError();

cleanup:
	if (process.hThread != NULL) CloseHandle(process.hThread);
	if (process.hProcess != NULL) CloseHandle(process.hProcess);
	if (arguments != NULL) LocalFree(arguments);
	if (child_command != NULL) HeapFree(GetProcessHeap(), 0, child_command);
	if (bridge != NULL) HeapFree(GetProcessHeap(), 0, bridge);
	if (original != NULL) HeapFree(GetProcessHeap(), 0, original);
	if (module != NULL) HeapFree(GetProcessHeap(), 0, module);
	return (int)exit_code;
}

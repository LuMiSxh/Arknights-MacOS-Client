/* SPDX-License-Identifier: MPL-2.0 */

#include <limits.h>
#include <windows.h>
#include <wchar.h>

/*
 * Detached Win32 controller for Bilibili's official PCGamePlatform.exe login
 * dialogs. It must not wrap, replace, or inject into the helper: its CEF host
 * and subprocess topology stay publisher-owned. Wine starts this controller
 * independently, and it only changes the selected dialog's Win32 placement,
 * leaving its rendering and hit testing with the official process.
 */

static const volatile char launcher_marker[] = "Arknights Client Bilibili window controller";
static const wchar_t login_class_prefix[] = L"CNativeLoginDlg_P_";

struct window_targets {
	HWND game;
	HWND login;
	ULONGLONG game_area;
};

static BOOL process_has_name(DWORD process_id, const wchar_t *expected) {
	wchar_t path[MAX_PATH];
	DWORD length = ARRAYSIZE(path);
	HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
	BOOL matches = FALSE;

	if (process == NULL) return FALSE;
	if (QueryFullProcessImageNameW(process, 0, path, &length)) {
		const wchar_t *name = wcsrchr(path, L'\\');
		name = name == NULL ? path : name + 1;
		matches = _wcsicmp(name, expected) == 0;
	}
	CloseHandle(process);
	return matches;
}

static BOOL is_login_window(HWND window) {
	wchar_t class_name[64];

	if (GetClassNameW(window, class_name, ARRAYSIZE(class_name)) == 0) return FALSE;
	return wcsncmp(class_name, login_class_prefix, ARRAYSIZE(login_class_prefix) - 1) == 0;
}

/* Select the largest visible Arknights window, then a visible PCGamePlatform.exe window whose
 * CNativeLoginDlg_P_ class covers Bilibili's agreement, QR, password, and recovery dialogs.
 * This deliberately excludes broad Chrome/CEF classes: their hidden host, renderer, and child
 * windows are not top-level login dialogs and must never be repositioned by the launcher. */
static BOOL CALLBACK find_windows(HWND window, LPARAM context_value) {
	struct window_targets *targets = (struct window_targets *)context_value;
	DWORD process_id = 0;
	RECT rectangle;
	LONGLONG width;
	LONGLONG height;
	ULONGLONG area;

	GetWindowThreadProcessId(window, &process_id);
	if (!IsWindowVisible(window) || !GetWindowRect(window, &rectangle)) return TRUE;
	width = (LONGLONG)rectangle.right - rectangle.left;
	height = (LONGLONG)rectangle.bottom - rectangle.top;
	if (width <= 0 || height <= 0) return TRUE;
	area = (ULONGLONG)width * (ULONGLONG)height;
	if (process_has_name(process_id, L"Arknights.exe")) {
		if (area > targets->game_area) {
			targets->game = window;
			targets->game_area = area;
		}
		return TRUE;
	}
	if (targets->login == NULL && process_has_name(process_id, L"PCGamePlatform.exe") &&
		is_login_window(window)) {
		targets->login = window;
	}
	return TRUE;
}

/* Center in Win32 screen coordinates, not Cocoa coordinates, so Wine keeps matching hit testing
 * and rendering geometry. HWND_TOP raises the dialog without activation; SWP_NOACTIVATE preserves
 * the game's keyboard focus. A new dialog is raised once even if already centered, but unchanged
 * 50 ms polls make no SetWindowPos call and therefore do not flash or churn its z-order. */
static BOOL center_login(HWND login, HWND game, BOOL raise) {
	RECT login_rectangle;
	RECT game_client;
	POINT client_origin = { 0 };
	LONGLONG login_width;
	LONGLONG login_height;
	LONGLONG client_width;
	LONGLONG client_height;
	LONGLONG x;
	LONGLONG y;

	if (!GetWindowRect(login, &login_rectangle) || !GetClientRect(game, &game_client) ||
		!ClientToScreen(game, &client_origin)) {
		return FALSE;
	}
	login_width = (LONGLONG)login_rectangle.right - login_rectangle.left;
	login_height = (LONGLONG)login_rectangle.bottom - login_rectangle.top;
	client_width = (LONGLONG)game_client.right - game_client.left;
	client_height = (LONGLONG)game_client.bottom - game_client.top;
	x = (client_width - login_width) / 2;
	y = (client_height - login_height) / 2;
	if (login_width <= 0 || login_height <= 0 || login_width > INT_MAX || login_height > INT_MAX ||
		x < INT_MIN || x > INT_MAX || y < INT_MIN || y > INT_MAX) {
		return FALSE;
	}
	if (login_rectangle.left != client_origin.x + (int)x ||
		login_rectangle.top != client_origin.y + (int)y) {
		return SetWindowPos(
			login,
			HWND_TOP,
			client_origin.x + (int)x,
			client_origin.y + (int)y,
			(int)login_width,
			(int)login_height,
			SWP_NOACTIVATE | SWP_SHOWWINDOW);
	}
	if (!raise) return TRUE;
	return SetWindowPos(
		login, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, wchar_t *command_line, int show) {
	BOOL saw_game = FALSE;
	unsigned int missing_game_ticks = 0;
	HWND previous_login = NULL;

	(void)instance;
	(void)previous;
	(void)command_line;
	(void)show;
	if (launcher_marker[0] == '\0') return 1;
	/* Polling avoids code inside the official helper and reacts quickly to game moves or
	 * replacement dialogs. Fifty milliseconds is responsive without continuous repositioning; after
	 * the game has appeared, twenty missing polls allow transient window changes but end this
	 * detached controller after one second, so it can never keep a Wine session alive by itself. */
	for (;;) {
		struct window_targets targets = { 0 };

		EnumWindows(find_windows, (LPARAM)&targets);
		if (targets.game != NULL) {
			saw_game = TRUE;
			missing_game_ticks = 0;
			if (targets.login != NULL) {
				if (center_login(targets.login, targets.game, targets.login != previous_login)) {
					previous_login = targets.login;
				}
			} else {
				previous_login = NULL;
			}
		} else if (saw_game && ++missing_game_ticks >= 20) {
			return 0;
		}
		Sleep(50);
	}
}

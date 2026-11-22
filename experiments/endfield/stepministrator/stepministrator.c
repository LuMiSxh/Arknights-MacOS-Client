// SPDX-License-Identifier: MPL-2.0

/*
 * Starts Arknights: Endfield as a child of the official Games.exe. Endfield.exe runs only
 * under that parent, and Games.exe alone idles without spawning the game. Games.exe stays
 * suspended and is terminated when the game exits, so no launcher process is left behind.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static void report_win32_failure(const wchar_t *call) {
    fwprintf(stderr, L"stepministrator: %ls failed: error %lu\n", call, GetLastError());
}

// Appends one argument, quoted so CommandLineToArgvW reads it back unchanged.
static wchar_t *append_quoted(wchar_t *out, const wchar_t *arg) {
    size_t backslashes = 0;
    *out++ = L'"';
    for (const wchar_t *p = arg;; p++) {
        if (*p == L'\\') {
            backslashes++;
        } else if (*p == L'"') {
            // Backslashes before a quote are doubled, and the quote itself is escaped.
            for (size_t i = 0; i < 2 * backslashes + 1; i++) {
                *out++ = L'\\';
            }
            *out++ = L'"';
            backslashes = 0;
        } else if (*p == L'\0') {
            // Trailing backslashes are doubled so they do not escape the closing quote.
            for (size_t i = 0; i < 2 * backslashes; i++) {
                *out++ = L'\\';
            }
            break;
        } else {
            for (size_t i = 0; i < backslashes; i++) {
                *out++ = L'\\';
            }
            *out++ = *p;
            backslashes = 0;
        }
    }
    *out++ = L'"';
    return out;
}

// Builds a writable command line from args. Each argument is quoted and separated by a space.
static wchar_t *build_command_line(wchar_t **args, int count) {
    size_t capacity = 1;
    for (int i = 0; i < count; i++) {
        // Each input character becomes at most two output characters, plus quotes and a space.
        capacity += 2 * wcslen(args[i]) + 3;
    }
    wchar_t *line = malloc(capacity * sizeof *line);
    if (!line) {
        return NULL;
    }
    wchar_t *out = line;
    for (int i = 0; i < count; i++) {
        if (i > 0) {
            *out++ = L' ';
        }
        out = append_quoted(out, args[i]);
    }
    *out = L'\0';
    return line;
}

// Cuts path down to its directory in place. Leaves an empty string when path has no directory.
static void truncate_to_directory(wchar_t *path) {
    wchar_t *slash = wcsrchr(path, L'\\');
    wchar_t *forward = wcsrchr(path, L'/');
    if (forward && (!slash || forward > slash)) {
        slash = forward;
    }
    if (!slash) {
        path[0] = L'\0';
        return;
    }
    // Keep the separator after a drive letter, so G:\Endfield.exe gives G:\ and not G:.
    wchar_t *end = (slash == path + 2 && path[1] == L':') ? slash + 1 : slash;
    *end = L'\0';
}

int wmain(int argc, wchar_t **argv) {
    if (argc < 3) {
        fwprintf(stderr,
                 L"usage: stepministrator.exe <Games.exe path> <game exe path> [game args...]\n");
        return 2;
    }

    PROCESS_INFORMATION games = {0};
    PROCESS_INFORMATION game = {0};
    STARTUPINFOW games_startup = {0};
    STARTUPINFOEXW game_startup = {0};
    LPPROC_THREAD_ATTRIBUTE_LIST attributes = NULL;
    SIZE_T attribute_size = 0;
    BOOL attributes_ready = FALSE;
    wchar_t *games_line = NULL;
    wchar_t *game_line = NULL;
    wchar_t *games_dir = NULL;
    wchar_t *game_dir = NULL;
    DWORD exit_code = 0;
    int status = 1;

    games_line = build_command_line(&argv[1], 1);
    game_line = build_command_line(&argv[2], argc - 2);
    games_dir = _wcsdup(argv[1]);
    game_dir = _wcsdup(argv[2]);
    if (!games_line || !game_line || !games_dir || !game_dir) {
        fwprintf(stderr, L"stepministrator: out of memory\n");
        goto cleanup;
    }
    truncate_to_directory(games_dir);
    truncate_to_directory(game_dir);

    games_startup.cb = sizeof games_startup;
    if (!CreateProcessW(argv[1], games_line, NULL, NULL, FALSE, CREATE_SUSPENDED, NULL,
                        games_dir[0] ? games_dir : NULL, &games_startup, &games)) {
        report_win32_failure(L"CreateProcessW(Games.exe)");
        goto cleanup;
    }
    // Games.exe stays suspended. Only its handle is needed, so the thread handle is not kept.
    CloseHandle(games.hThread);

    // The first call only reports the size and fails by design.
    InitializeProcThreadAttributeList(NULL, 1, 0, &attribute_size);
    attributes = malloc(attribute_size);
    if (!attributes) {
        fwprintf(stderr, L"stepministrator: out of memory\n");
        goto cleanup;
    }
    if (!InitializeProcThreadAttributeList(attributes, 1, 0, &attribute_size)) {
        report_win32_failure(L"InitializeProcThreadAttributeList");
        goto cleanup;
    }
    attributes_ready = TRUE;
    if (!UpdateProcThreadAttribute(attributes, 0, PROC_THREAD_ATTRIBUTE_PARENT_PROCESS,
                                   &games.hProcess, sizeof games.hProcess, NULL, NULL)) {
        report_win32_failure(L"UpdateProcThreadAttribute");
        goto cleanup;
    }

    game_startup.StartupInfo.cb = sizeof game_startup;
    game_startup.lpAttributeList = attributes;
    if (!CreateProcessW(argv[2], game_line, NULL, NULL, FALSE, EXTENDED_STARTUPINFO_PRESENT,
                        NULL, game_dir[0] ? game_dir : NULL, &game_startup.StartupInfo, &game)) {
        report_win32_failure(L"CreateProcessW(game)");
        goto cleanup;
    }
    CloseHandle(game.hThread);
    fwprintf(stderr, L"Games.exe pid %lu\n", games.dwProcessId);
    fwprintf(stderr, L"game pid %lu\n", game.dwProcessId);

    if (WaitForSingleObject(game.hProcess, INFINITE) == WAIT_FAILED) {
        report_win32_failure(L"WaitForSingleObject(game)");
        goto cleanup;
    }
    if (!GetExitCodeProcess(game.hProcess, &exit_code)) {
        report_win32_failure(L"GetExitCodeProcess(game)");
        goto cleanup;
    }
    status = (int)exit_code;

cleanup:
    if (games.hProcess) {
        if (!TerminateProcess(games.hProcess, 1)) {
            report_win32_failure(L"TerminateProcess(Games.exe)");
        }
        CloseHandle(games.hProcess);
    }
    if (game.hProcess) {
        CloseHandle(game.hProcess);
    }
    if (attributes_ready) {
        DeleteProcThreadAttributeList(attributes);
    }
    free(attributes);
    free(games_line);
    free(game_line);
    free(games_dir);
    free(game_dir);
    return status;
}

// SPDX-License-Identifier: MPL-2.0

#import <CoreGraphics/CoreGraphics.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/*
 * Process-local macOS presentation policy for Bilibili's PCGamePlatform.exe.
 *
 * The Bilibili login dialogs live in PCGamePlatform.exe, a different Wine process
 * from the game. The Win32 controller centers and raises them, but it cannot set
 * the macOS window level or order the Cocoa window. This bridge keeps the login
 * window directly above the game: other applications can cover it, and it fades
 * out while the game is minimized, hidden, or on another Space.
 *
 * It deliberately does not change activation. The login window has text fields,
 * so the Notices click-to-activate behavior would steal keyboard focus.
 *
 * Wine passes the game's DYLD_INSERT_LIBRARIES to every child process, so this
 * dylib loads in the game and in PCGamePlatform. It links no AppKit at load:
 * AppKit is opened only after the process is identified as the platform process,
 * which keeps the game's menu bar and application name untouched. The Win32
 * controller writes a zero-width suffix into the login window title so the bridge
 * can identify the right NSWindow without guessing from its size.
 */

static const volatile char launcher_marker[] = "Arknights Client Bilibili window bridge";
static const char login_marker[] = "\xE2\x80\x8B\xE2\x80\x8C\xE2\x80\x8B\xE2\x80\x8C"
                                   "\xE2\x80\x8B\xE2\x80\x8C\xE2\x80\x8B\xE2\x80\x8C";

static dispatch_source_t gate_timer;
static dispatch_source_t presentation_timer;
static BOOL appkit_ready;
static BOOL platform_process;
static BOOL inactive_process;
static BOOL login_hidden;
static CGWindowID tracked_game_window;
static unsigned int game_search_countdown;
static CGWindowID logged_game_window;

typedef signed char AKBool;
typedef long AKInteger;
typedef unsigned long AKUInteger;
typedef double AKFloat;

typedef struct {
	double x;
	double y;
} AKPoint;

typedef struct {
	double width;
	double height;
} AKSize;

typedef struct {
	AKPoint origin;
	AKSize size;
} AKRect;

static const AKInteger window_above = 1;
static const AKUInteger collection_join_all_spaces = 1UL << 0;
static const AKUInteger collection_stationary = 1UL << 4;
static const AKUInteger collection_ignores_cycle = 1UL << 6;
static const AKUInteger collection_fullscreen_primary = 1UL << 7;
static const AKUInteger collection_fullscreen_auxiliary = 1UL << 8;

struct game_window {
	CGWindowID number;
	pid_t process_id;
};

struct game_state {
	BOOL exists;
	BOOL on_screen;
	AKInteger layer;
};

static BOOL dictionary_bool(CFDictionaryRef dictionary, CFStringRef key, BOOL fallback) {
	CFNumberRef number = CFDictionaryGetValue(dictionary, key);
	int value;

	if (number == NULL || !CFNumberGetValue(number, kCFNumberIntType, &value))
		return fallback;
	return value != 0;
}

static AKInteger dictionary_integer(CFDictionaryRef dictionary, CFStringRef key) {
	CFNumberRef number = CFDictionaryGetValue(dictionary, key);
	AKInteger value = 0;

	if (number != NULL)
		CFNumberGetValue(number, kCFNumberLongType, &value);
	return value;
}

static void
dictionary_string(CFDictionaryRef dictionary, CFStringRef key, char *buffer, size_t size) {
	CFStringRef string = CFDictionaryGetValue(dictionary, key);

	buffer[0] = '\0';
	if (string != NULL && CFGetTypeID(string) == CFStringGetTypeID())
		CFStringGetCString(string, buffer, size, kCFStringEncodingUTF8);
}

static BOOL has_suffix(const char *value, const char *suffix) {
	size_t value_length = strlen(value);
	size_t suffix_length = strlen(suffix);

	return value_length >= suffix_length &&
	       memcmp(value + value_length - suffix_length, suffix, suffix_length) == 0;
}

/* The largest on-screen window owned by an "Arknights" process, excluding this
 * process and the macOS launcher. Mirrors the Notices bridge's lookup. */
static struct game_window game_window_info(void) {
	CFArrayRef windows = CGWindowListCopyWindowInfo(
	    kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
	struct game_window result = {kCGNullWindowID, 0};
	CGFloat largest_area = 0.0;

	if (windows == NULL)
		return result;
	for (CFIndex i = 0; i < CFArrayGetCount(windows); i++) {
		CFDictionaryRef description = CFArrayGetValueAtIndex(windows, i);
		char owner[256];
		char name[256];
		pid_t owner_pid = (pid_t)dictionary_integer(description, kCGWindowOwnerPID);
		AKInteger layer = dictionary_integer(description, kCGWindowLayer);
		CFDictionaryRef bounds_description;
		CGRect bounds;
		CGFloat area;

		if (owner_pid == getpid() || layer < 0)
			continue;
		dictionary_string(description, kCGWindowOwnerName, owner, sizeof(owner));
		dictionary_string(description, kCGWindowName, name, sizeof(name));
		// Skip this launcher's own window, titled "Arknights Client".
		if (strcmp(owner, "Arknights Client") == 0 || strcmp(name, "Arknights Client") == 0)
			continue;
		if (strncmp(owner, "Arknights", 9) != 0 && strncmp(name, "Arknights", 9) != 0)
			continue;
		bounds_description = CFDictionaryGetValue(description, kCGWindowBounds);
		if (bounds_description == NULL ||
		    !CGRectMakeWithDictionaryRepresentation(bounds_description, &bounds)) {
			continue;
		}
		area = bounds.size.width * bounds.size.height;
		if (area <= largest_area)
			continue;
		largest_area = area;
		result.number = (CGWindowID)dictionary_integer(description, kCGWindowNumber);
		result.process_id = owner_pid;
	}
	CFRelease(windows);
	return result;
}

static struct game_state tracked_game_state(CGWindowID number) {
	struct game_state state = {NO, NO, 0};
	CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, number);

	if (windows == NULL)
		return state;
	if (CFArrayGetCount(windows) > 0) {
		CFDictionaryRef description = CFArrayGetValueAtIndex(windows, 0);

		state.exists = YES;
		state.on_screen = dictionary_bool(description, kCGWindowIsOnscreen, NO);
		state.layer = dictionary_integer(description, kCGWindowLayer);
	}
	CFRelease(windows);
	return state;
}

/* The controller writes the zero-width marker into the login window title.
 * Only the main platform process owns that window; PCGamePlatform's CEF children
 * do not. Checking the marker in the WindowServer before opening AppKit keeps
 * AppKit out of those children, where initializing it can fault the webview. */
static BOOL process_has_login_marker(void) {
	CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
	BOOL result = NO;

	if (windows == NULL)
		return NO;
	for (CFIndex i = 0; i < CFArrayGetCount(windows); i++) {
		CFDictionaryRef description = CFArrayGetValueAtIndex(windows, i);
		char name[512];

		if ((pid_t)dictionary_integer(description, kCGWindowOwnerPID) != getpid())
			continue;
		dictionary_string(description, kCGWindowName, name, sizeof(name));
		if (strstr(name, login_marker) != NULL) {
			result = YES;
			break;
		}
	}
	CFRelease(windows);
	return result;
}

/* A process named PCGamePlatform may be the main helper or one of its CEF
 * children. Without the login marker, keep polling rather than opening AppKit.
 * A process whose windows belong to another name is the game or the Notices
 * helper and can stop. */
static BOOL process_may_be_platform(void) {
	CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
	BOOL has_window = NO;
	BOOL platform_name = NO;

	if (windows == NULL)
		return YES;
	for (CFIndex i = 0; i < CFArrayGetCount(windows); i++) {
		CFDictionaryRef description = CFArrayGetValueAtIndex(windows, i);
		char owner[256];

		if ((pid_t)dictionary_integer(description, kCGWindowOwnerPID) != getpid())
			continue;
		has_window = YES;
		dictionary_string(description, kCGWindowOwnerName, owner, sizeof(owner));
		if (strstr(owner, "PCGamePlatform") != NULL)
			platform_name = YES;
	}
	CFRelease(windows);
	if (!has_window)
		return YES;
	return platform_name;
}

static BOOL load_appkit(void) {
	if (appkit_ready)
		return YES;
	if (dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_LAZY | RTLD_LOCAL) ==
	    NULL) {
		return NO;
	}
	if (objc_getClass("NSApplication") == NULL)
		return NO;
	appkit_ready = YES;
	return YES;
}

static id send_id(id object, const char *selector) {
	return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static AKInteger send_integer(id object, const char *selector) {
	return ((AKInteger (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static void send_void_integer(id object, const char *selector, AKInteger value) {
	((void (*)(id, SEL, AKInteger))objc_msgSend)(object, sel_registerName(selector), value);
}

static AKUInteger send_uinteger(id object, const char *selector) {
	return ((AKUInteger (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static void send_void_uinteger(id object, const char *selector, AKUInteger value) {
	((void (*)(id, SEL, AKUInteger))objc_msgSend)(object, sel_registerName(selector), value);
}

static AKBool send_bool(id object, const char *selector) {
	return ((AKBool (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static void send_void_bool(id object, const char *selector, AKBool value) {
	((void (*)(id, SEL, AKBool))objc_msgSend)(object, sel_registerName(selector), value);
}

static AKFloat send_float(id object, const char *selector) {
	return ((AKFloat (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static void send_void_float(id object, const char *selector, AKFloat value) {
	((void (*)(id, SEL, AKFloat))objc_msgSend)(object, sel_registerName(selector), value);
}

static AKRect send_rect(id object, const char *selector) {
	return ((AKRect (*)(id, SEL))objc_msgSend)(object, sel_registerName(selector));
}

static void
send_void_integer_integer(id object, const char *selector, AKInteger first, AKInteger second) {
	((void (*)(id, SEL, AKInteger, AKInteger))objc_msgSend)(
	    object, sel_registerName(selector), first, second);
}

/* The controller writes this suffix into the login window title. It is eight
 * zero-width characters, so the visible title does not change. */
static id login_window(void) {
	id app_class = (id)objc_getClass("NSApplication");
	id app;
	id windows;
	AKUInteger count;
	id best = nil;
	AKFloat best_area = 0.0;
	AKUInteger i;

	if (app_class == NULL)
		return nil;
	app = send_id(app_class, "sharedApplication");
	if (app == nil)
		return nil;
	windows = send_id(app, "windows");
	if (windows == nil)
		return nil;
	count = send_uinteger(windows, "count");
	for (i = 0; i < count; i++) {
		id window = ((id (*)(id, SEL, AKUInteger))objc_msgSend)(
		    windows, sel_registerName("objectAtIndex:"), i);
		id title;
		const char *utf8;
		AKRect frame;
		AKFloat area;

		if (window == nil || !send_bool(window, "isVisible"))
			continue;
		title = send_id(window, "title");
		utf8 = title != nil
		           ? ((const char *(*)(id, SEL))objc_msgSend)(title, sel_registerName("UTF8String"))
		           : NULL;
		if (utf8 == NULL || !has_suffix(utf8, login_marker))
			continue;
		frame = send_rect(window, "frame");
		area = frame.size.width * frame.size.height;
		if (area > best_area) {
			best = window;
			best_area = area;
		}
	}
	return best;
}

static BOOL login_is_directly_above(id window, CGWindowID game) {
	AKInteger number = send_integer(window, "windowNumber");
	CFArrayRef below =
	    CGWindowListCreate(kCGWindowListOptionOnScreenBelowWindow, (CGWindowID)number);
	BOOL result = NO;

	if (below == NULL)
		return NO;
	if (CFArrayGetCount(below) > 0)
		result = (CGWindowID)(uintptr_t)CFArrayGetValueAtIndex(below, 0) == game;
	CFRelease(below);
	return result;
}

static void configure_login(id window) {
	AKUInteger behavior = send_uinteger(window, "collectionBehavior");
	AKUInteger wanted = behavior;

	wanted &= ~collection_fullscreen_primary;
	wanted |= collection_join_all_spaces | collection_stationary | collection_ignores_cycle |
	          collection_fullscreen_auxiliary;
	if (wanted != behavior)
		send_void_uinteger(window, "setCollectionBehavior:", wanted);
	if (send_bool(window, "hidesOnDeactivate"))
		send_void_bool(window, "setHidesOnDeactivate:", NO);
}

/* Wine owns the window's visibility and alpha. Fade the frame view and let clicks
 * pass through instead of ordering the window out. */
static void set_login_hidden(id window, BOOL hidden) {
	id content = send_id(window, "contentView");
	id frame = content != nil ? send_id(content, "superview") : nil;
	id target = frame != nil ? frame : content;
	AKFloat alpha = hidden ? 0.0 : 1.0;

	if (target != nil && send_float(target, "alphaValue") != alpha)
		send_void_float(target, "setAlphaValue:", alpha);
	if (send_bool(window, "ignoresMouseEvents") != hidden)
		send_void_bool(window, "setIgnoresMouseEvents:", hidden);
	login_hidden = hidden;
}

static void maintain_presentation(void) {
	id window;
	struct game_state game = {NO, NO, 0};

	if (!platform_process || !load_appkit())
		return;
	window = login_window();
	if (window == nil)
		return;

	if (tracked_game_window != kCGNullWindowID) {
		game = tracked_game_state(tracked_game_window);
		if (!game.exists)
			tracked_game_window = kCGNullWindowID;
	}
	if (tracked_game_window == kCGNullWindowID) {
		if (game_search_countdown > 0) {
			game_search_countdown--;
		} else {
			struct game_window found = game_window_info();

			game_search_countdown = 15;
			if (found.number != kCGNullWindowID) {
				tracked_game_window = found.number;
				game = tracked_game_state(found.number);
				if (logged_game_window != found.number) {
					fprintf(
					    stderr,
					    "bilibili-window-bridge: found login=%ld game=%u pid=%d\n",
					    (long)send_integer(window, "windowNumber"),
					    found.number,
					    found.process_id);
					logged_game_window = found.number;
				}
			}
		}
	}

	/* Until the game window is known, leave the login at Wine's own level. */
	if (tracked_game_window == kCGNullWindowID) {
		set_login_hidden(window, NO);
		configure_login(window);
		return;
	}

	set_login_hidden(window, !game.on_screen);
	configure_login(window);
	if (!game.on_screen)
		return;

	if (send_integer(window, "level") != game.layer)
		send_void_integer(window, "setLevel:", game.layer);
	if (!login_is_directly_above(window, tracked_game_window))
		send_void_integer_integer(
		    window, "orderWindow:relativeTo:", window_above, (AKInteger)tracked_game_window);
}

static void gate_tick(void) {
	if (inactive_process)
		return;
	if (!process_has_login_marker()) {
		if (!process_may_be_platform()) {
			inactive_process = YES;
			if (gate_timer != NULL)
				dispatch_source_cancel(gate_timer);
			fprintf(stderr, "bilibili-window-bridge: inactive pid=%d\n", getpid());
		}
		return;
	}

	platform_process = YES;
	if (gate_timer != NULL)
		dispatch_source_cancel(gate_timer);
	fprintf(stderr, "bilibili-window-bridge: login marker in pid=%d\n", getpid());
	dispatch_async(dispatch_get_main_queue(), ^{
	  presentation_timer =
		  dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	  dispatch_source_set_timer(
		  presentation_timer,
		  dispatch_time(DISPATCH_TIME_NOW, 0),
		  NSEC_PER_MSEC * 33,
		  NSEC_PER_MSEC * 5);
	  dispatch_source_set_event_handler(presentation_timer, ^{
		maintain_presentation();
	  });
	  dispatch_resume(presentation_timer);
	});
}

__attribute__((constructor)) static void install_bilibili_window_bridge(void) {
	if (launcher_marker[0] == '\0')
		return;
	fprintf(stderr, "bilibili-window-bridge: loaded pid=%d\n", getpid());
	dispatch_async(dispatch_get_main_queue(), ^{
	  gate_timer =
		  dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	  dispatch_source_set_timer(
		  gate_timer,
		  dispatch_time(DISPATCH_TIME_NOW, 0),
		  NSEC_PER_MSEC * 500,
		  NSEC_PER_MSEC * 100);
	  dispatch_source_set_event_handler(gate_timer, ^{
		gate_tick();
	  });
	  dispatch_resume(gate_timer);
	});
}
